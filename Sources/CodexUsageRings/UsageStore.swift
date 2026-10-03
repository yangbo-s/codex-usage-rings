import AppKit
import Combine
import UsageCore

struct AccountState {
    var usage: AccountUsage?
    var email: String?
    var plan: String?
    var updatedAt: Date?
    var isRefreshing = false
    var error: String?

    var snapshot: RateSnapshot? { usage?.limits }
    var rings: RingPresentation { usage?.rings ?? RingPresentation() }

    var isStale: Bool {
        let interval = RefreshPolicy.interval(lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
        return error != nil || updatedAt.map { Date().timeIntervalSince($0) > interval * 2.2 } == true
    }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var settings: Settings
    @Published private(set) var states: [String: AccountState] = [:]
    @Published var selectedID: String?
    @Published var managing = false
    @Published var message: String?
    @Published private(set) var connecting = false
    @Published private(set) var loginURL: URL?
    @Published private(set) var pendingProfile: Profile?

    private let dataDirectory: URL
    private var clients: [String: CodexClient] = [:]
    private var timer: Timer?
    private var loginDeadline: Task<Void, Never>?
    private var canPersist = true
    private var wakeObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var powerObserver: NSObjectProtocol?
    private var sleeping = false
    private var refreshingAll = false
    private var failures: [String: Int] = [:]
    private var nextRetries: [String: Date] = [:]
    private let makeClient: (URL?) -> CodexClient

    init(dataDirectory: URL? = nil, clientFactory: ((URL?) -> CodexClient)? = nil) {
        self.dataDirectory = dataDirectory ?? Self.defaultDirectory
        makeClient = clientFactory ?? { CodexClient(home: $0) }
        let file = self.dataDirectory.appendingPathComponent("settings.json")
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                settings = try JSONDecoder().decode(Settings.self, from: Data(contentsOf: file))
            } else {
                settings = Settings()
            }
        } catch {
            settings = Settings()
            canPersist = false
            message = "设置文件无法读取，已保留原文件。请修复设置文件后重新打开。"
        }
        selectedID = visibleProfiles.first?.id
    }

    static var defaultDirectory: URL {
        if let path = ProcessInfo.processInfo.environment["USAGE_RINGS_DATA_DIR"] {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Codex Usage Rings", isDirectory: true)
    }

    var visibleProfiles: [Profile] { settings.profiles }
    var realProfiles: [Profile] { settings.profiles }

    var isRefreshing: Bool { states.values.contains { $0.isRefreshing } }

    func start() {
        scheduleTimer()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in
            self?.sleeping = false
            self?.scheduleTimer()
            await self?.refreshAll(minimumAge: 60)
        } }
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in
            self?.sleeping = true
            self?.timer?.invalidate()
            self?.clients.values.forEach { $0.stop() }
            self?.cancelLogin()
        } }
        powerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.scheduleTimer() } }
        Task {
            if settings.profiles.isEmpty && settings.autoConnectLocal && canPersist {
                await connectLocal()
            } else {
                await refreshAll()
            }
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        guard !sleeping else { return }
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let interval = RefreshPolicy.interval(lowPower: lowPower)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshAll(minimumAge: interval) }
        }
        timer?.tolerance = RefreshPolicy.tolerance(lowPower: lowPower)
    }

    func update(_ id: String, edit: (inout Profile) -> Void) {
        guard let index = settings.profiles.firstIndex(where: { $0.id == id }) else { return }
        edit(&settings.profiles[index])
        save()
    }

    func remove(_ profile: Profile) {
        clients.removeValue(forKey: profile.id)?.stop()
        states.removeValue(forKey: profile.id)
        failures.removeValue(forKey: profile.id)
        nextRetries.removeValue(forKey: profile.id)
        settings.profiles.removeAll { $0.id == profile.id }
        settings.autoConnectLocal = false
        if selectedID == profile.id { selectedID = visibleProfiles.first?.id }
        save()
    }

    func refreshAll(minimumAge: TimeInterval = 0, force: Bool = false) async {
        guard !sleeping, !refreshingAll else { return }
        refreshingAll = true
        defer { refreshingAll = false }
        // Serial reads keep multi-account CPU and memory bursts bounded.
        for profile in realProfiles {
            guard !sleeping else { break }
            if RefreshPolicy.shouldRefresh(lastUpdate: states[profile.id]?.updatedAt,
                                           nextRetry: nextRetries[profile.id], now: Date(),
                                           minimumAge: minimumAge, force: force) {
                await refresh(profile)
            }
        }
    }

    func refresh(_ profile: Profile) async {
        guard !sleeping, states[profile.id]?.isRefreshing != true else { return }
        states[profile.id, default: AccountState()].isRefreshing = true
        defer {
            // Keep no app-server running between reads. Pending OAuth has its own lifecycle.
            clients.removeValue(forKey: profile.id)?.stop()
            if settings.profiles.contains(where: { $0.id == profile.id }) {
                states[profile.id, default: AccountState()].isRefreshing = false
            }
        }
        do {
            let client = client(for: profile)
            let account = try await client.account()
            let usage = try await client.usage()
            guard settings.profiles.contains(where: { $0.id == profile.id }) else { return }
            states[profile.id] = AccountState(usage: usage, email: account.email,
                                              plan: account.planType, updatedAt: Date())
            failures.removeValue(forKey: profile.id)
            nextRetries.removeValue(forKey: profile.id)
        } catch {
            guard settings.profiles.contains(where: { $0.id == profile.id }) else { return }
            guard !sleeping else { return }
            states[profile.id, default: AccountState()].error = Self.describe(error)
            failures[profile.id, default: 0] += 1
            nextRetries[profile.id] = Date().addingTimeInterval(RefreshPolicy.failureDelay(attempt: failures[profile.id] ?? 1))
        }
    }

    func connectLocal() async {
        guard !connecting, pendingProfile == nil else { return }
        if let existing = realProfiles.first(where: { $0.kind == .local }) {
            selectedID = existing.id
            await refresh(existing)
            return
        }
        connecting = true
        message = nil
        defer { connecting = false }
        let profile = Profile(name: "本机账户", kind: .local)
        defer { clients.removeValue(forKey: profile.id)?.stop() }
        do {
            let client = client(for: profile)
            let account = try await client.account()
            let usage = try await client.usage()
            settings.profiles.append(profile)
            settings.autoConnectLocal = false
            save()
            states[profile.id] = AccountState(usage: usage, email: account.email,
                                              plan: account.planType, updatedAt: Date())
            selectedID = profile.id
            managing = false
        } catch {
            clients.removeValue(forKey: profile.id)?.stop()
            message = Self.describe(error)
        }
    }

    func addAccount() async {
        guard !connecting, pendingProfile == nil else { return }
        connecting = true
        message = nil
        let profile = Profile(name: "账户 \(realProfiles.count + 1)", kind: .managed)
        pendingProfile = profile
        let client = client(for: profile)
        client.notification = { [weak self] method, params in
            guard method == "account/login/completed", let self,
                  self.pendingProfile?.id == profile.id else { return }
            if params["success"] as? Bool == true {
                Task { await self.finishLogin(profile) }
            } else {
                self.message = "登录未完成，请重新添加账户。"
                self.cancelLogin()
            }
        }
        do {
            let url = try await client.beginLogin()
            guard pendingProfile?.id == profile.id else { return }
            loginURL = url
            connecting = false
            NSWorkspace.shared.open(url)
            loginDeadline = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 300_000_000_000) } catch { return }
                guard let self, self.pendingProfile?.id == profile.id else { return }
                self.message = "登录等待已结束，请重新添加账户。"
                self.cancelLogin()
            }
        } catch {
            guard pendingProfile?.id == profile.id else { return }
            message = Self.describe(error)
            cancelLogin()
        }
    }

    private func finishLogin(_ profile: Profile) async {
        guard pendingProfile?.id == profile.id else { return }
        loginDeadline?.cancel()
        loginURL = nil
        // Register first so transient usage failures do not throw away a successful login.
        settings.profiles.append(profile)
        settings.autoConnectLocal = false
        pendingProfile = nil
        connecting = false
        clients[profile.id]?.notification = nil
        save()
        selectedID = profile.id
        await refresh(profile)
        managing = false
    }

    func cancelLogin() {
        loginDeadline?.cancel()
        if let profile = pendingProfile { clients.removeValue(forKey: profile.id)?.stop() }
        pendingProfile = nil
        loginURL = nil
        connecting = false
    }

    private func client(for profile: Profile) -> CodexClient {
        if let client = clients[profile.id] { return client }
        let home = profile.kind == .managed
            ? dataDirectory.appendingPathComponent("profiles").appendingPathComponent(profile.id) : nil
        let client = makeClient(home)
        clients[profile.id] = client
        return client
    }

    private func save() {
        guard canPersist else { return }
        do {
            try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            let data = try JSONEncoder().encode(settings)
            try data.write(to: dataDirectory.appendingPathComponent("settings.json"), options: .atomic)
        } catch {
            message = "设置未能保存：\(error.localizedDescription)"
        }
    }

    private static func describe(_ error: Error) -> String {
        if error is DecodingError { return ClientError.protocolError.localizedDescription }
        return String(error.localizedDescription.prefix(240))
    }

    func stop() {
        sleeping = true
        timer?.invalidate()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) }
        loginDeadline?.cancel()
        clients.values.forEach { $0.stop() }
    }
}
