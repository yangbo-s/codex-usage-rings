import AppKit
import Combine
import Sparkle

/// Keeps Sparkle alive independently of the transient menu bar popover.
@MainActor
final class SoftwareUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecks = false
    @Published private(set) var automaticallyDownloads = false
    @Published private(set) var sessionInProgress = false
    @Published private(set) var lastCheck: Date?
    @Published private(set) var error: String?
    @Published private(set) var availableVersion: String?
    let version: String
    private let updater: SPUUpdater
    private let reminders = UpdateReminders()

    // A separate bundle and a stopped updater let tests exercise real Sparkle
    // preferences without network requests or touching the installed app's defaults.
    init(start: Bool = true, bundle: Bundle = .main) {
        version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发构建"
        let driver = SPUStandardUserDriver(hostBundle: bundle, delegate: reminders)
        updater = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: driver, delegate: nil)
        reminders.$availableVersion.assign(to: &$availableVersion)
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticallyChecks)
        updater.publisher(for: \.automaticallyDownloadsUpdates).assign(to: &$automaticallyDownloads)
        updater.publisher(for: \.sessionInProgress).assign(to: &$sessionInProgress)
        updater.publisher(for: \.lastUpdateCheckDate).assign(to: &$lastCheck)
        if start {
            do { try updater.start() }
            catch { self.error = "更新服务未能启动：\(error.localizedDescription)" }
        }
    }

    func setAutomaticallyChecks(_ enabled: Bool) {
        updater.automaticallyChecksForUpdates = enabled
    }

    func setAutomaticallyDownloads(_ enabled: Bool) {
        updater.automaticallyDownloadsUpdates = enabled
    }

    func checkForUpdates() {
        guard canCheckForUpdates, error == nil else { return }
        NSApp.activate(ignoringOtherApps: true)
        updater.checkForUpdates()
    }
}

/// A menu bar app needs a visible reminder when Sparkle defers its update window.
@MainActor
private final class UpdateReminders: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    @Published var availableVersion: String?
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        availableVersion = update.displayVersionString
    }

    func standardUserDriverWillFinishUpdateSession() {
        availableVersion = nil
    }
}
