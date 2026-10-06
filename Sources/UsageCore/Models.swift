import Foundation

public struct UsageWindow: Codable, Equatable {
    public var usedPercent: Double?
    public var windowDurationMins: Int?
    public var resetsAt: Double?

    public init(usedPercent: Double?, windowDurationMins: Int?, resetsAt: Double?) {
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }

    public var remaining: Double? {
        guard let usedPercent, usedPercent.isFinite else { return nil }
        return min(100, max(0, 100 - usedPercent))
    }

    public var percentage: String {
        remaining.map { "\(Int($0.rounded()))%" } ?? "—"
    }

    public var title: String {
        guard let minutes = windowDurationMins, minutes > 0 else { return "额度窗口" }
        if minutes == 10_080 { return "每周额度" }
        if minutes % 1_440 == 0 { return "\(minutes / 1_440) 天额度" }
        if minutes % 60 == 0 { return "\(minutes / 60) 小时额度" }
        return "\(minutes) 分钟额度"
    }

    public func resetDescription(now: Date = Date()) -> String {
        guard let resetsAt, resetsAt.isFinite, resetsAt > 0 else { return "重置时间未知" }
        let seconds = resetsAt - now.timeIntervalSince1970
        guard seconds > 0 else { return "等待额度更新" }
        // Round up so a future reset never claims to have already happened.
        let minutes = min(Int(ceil(min(seconds, 315_360_000) / 60)), 5_256_000)
        if minutes >= 1_440 { return "\(minutes / 1_440) 天 \((minutes % 1_440) / 60) 小时后重置" }
        if minutes >= 60 { return "\(minutes / 60) 小时 \(minutes % 60) 分钟后重置" }
        return "\(minutes) 分钟后重置"
    }
}

public struct RateSnapshot: Codable, Equatable {
    public var limitId: String?
    public var limitName: String?
    public var planType: String?
    public var primary: UsageWindow?
    public var secondary: UsageWindow?
    public var credits: CreditBalance?

    public init(primary: UsageWindow?, secondary: UsageWindow?, planType: String? = nil,
                credits: CreditBalance? = nil) {
        self.primary = primary
        self.secondary = secondary
        self.planType = planType
        self.credits = credits
    }

    private enum CodingKeys: String, CodingKey {
        case limitId, limitName, planType, primary, secondary, credits
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        limitId = try values.decodeIfPresent(String.self, forKey: .limitId)
        limitName = try values.decodeIfPresent(String.self, forKey: .limitName)
        planType = try values.decodeIfPresent(String.self, forKey: .planType)
        primary = try values.decodeIfPresent(UsageWindow.self, forKey: .primary)
        secondary = try values.decodeIfPresent(UsageWindow.self, forKey: .secondary)
        // Optional credit details must not discard valid quota windows.
        credits = try? values.decodeIfPresent(CreditBalance.self, forKey: .credits)
    }
}

public struct RateResponse: Decodable {
    public var rateLimits: RateSnapshot?
    public var rateLimitsByLimitId: [String: RateSnapshot]?
    public var rateLimitResetCredits: ResetCredits?

    public struct ResetCredits: Decodable {
        public var availableCount: Int?
        public var credits: [ResetCredit]?

        private enum CodingKeys: String, CodingKey { case availableCount, credits }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            availableCount = try container.decodeIfPresent(Int.self, forKey: .availableCount)
            // Optional details must not make an otherwise valid quota unreadable.
            credits = try? container.decodeIfPresent([ResetCredit].self, forKey: .credits)
        }
    }

    public var codex: RateSnapshot? {
        if let value = rateLimitsByLimitId?["codex"] { return value }
        if let rateLimits { return rateLimits }
        return rateLimitsByLimitId?.sorted { $0.key < $1.key }.first?.value
    }

    public var usage: AccountUsage? {
        codex.map { AccountUsage(limits: $0, bankedResetCount: rateLimitResetCredits?.availableCount,
                                resetCredits: rateLimitResetCredits?.credits) }
    }
}

public struct AccountUsage: Equatable {
    public var limits: RateSnapshot
    public var bankedResetCount: Int?
    public var resetCredits: [ResetCredit]?

    public init(limits: RateSnapshot, bankedResetCount: Int?, resetCredits: [ResetCredit]? = nil) {
        self.limits = limits
        // A missing or malformed count is unknown, never an invented zero.
        self.bankedResetCount = bankedResetCount.flatMap { $0 >= 0 ? $0 : nil }
        self.resetCredits = resetCredits
    }

    public var usesCreditFallback: Bool {
        guard limits.credits?.isAvailable == true else { return false }
        // This indicates fallback availability, not a claim that a debit was observed.
        return [limits.primary, limits.secondary].contains { $0?.remaining == 0 }
    }

    public var rings: RingPresentation {
        let windows = [limits.primary, limits.secondary].compactMap { $0 }
        let fiveHour = windows.first { $0.windowDurationMins == 300 }
        let other = windows.filter { $0.windowDurationMins != 300 }
            .max { ($0.windowDurationMins ?? 0) < ($1.windowDurationMins ?? 0) }
        // Only real windows are drawn; a lone five-hour window is a single ring.
        return RingPresentation(outer: other ?? fiveHour,
                                inner: other == nil ? nil : fiveHour,
                                bankedResetCount: bankedResetCount, usesCredits: usesCreditFallback)
    }
}

public struct RingPresentation: Equatable {
    public var outer: UsageWindow?
    public var inner: UsageWindow?
    public var bankedResetCount: Int?
    public var usesCredits: Bool

    public init(outer: UsageWindow? = nil, inner: UsageWindow? = nil, bankedResetCount: Int? = nil,
                usesCredits: Bool = false) {
        self.outer = outer
        self.inner = inner
        self.bankedResetCount = bankedResetCount
        self.usesCredits = usesCredits
    }

    public var percentage: String { outer?.percentage ?? "—" }
    public var number: String { usesCredits ? "C" : outer?.remaining.map { String(Int($0.rounded())) } ?? "—" }
    public var accessibilitySummary: String {
        usesCredits ? "额度已耗尽，尚有 Credits" : "剩余 \(percentage)"
    }
    public var isNested: Bool { inner != nil }
}

public struct AccountResponse: Decodable {
    public struct Account: Decodable {
        public var type: String
        public var email: String?
        public var planType: String?
    }
    public var account: Account?
}

public enum ProfileKind: String, Codable {
    case local, managed
    // Decode and discard old preview records without discarding real accounts.
    case legacyDemo = "demo"
}

public struct Profile: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var kind: ProfileKind
    public init(id: String = UUID().uuidString, name: String, kind: ProfileKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

public struct Settings: Codable, Equatable {
    public var profiles: [Profile]
    public var autoConnectLocal: Bool
    public var autoHideEnabled: Bool
    public private(set) var autoHideDelaySeconds: Int
    public private(set) var menuBarRingLimit: Int?

    public init(profiles: [Profile] = [], autoConnectLocal: Bool = true,
                autoHideEnabled: Bool = true, autoHideDelaySeconds: Int = 3,
                menuBarRingLimit: Int? = nil) {
        self.profiles = profiles.filter { $0.kind != .legacyDemo }
        self.autoConnectLocal = autoConnectLocal
        self.autoHideEnabled = autoHideEnabled
        self.autoHideDelaySeconds = min(300, max(1, autoHideDelaySeconds))
        self.menuBarRingLimit = menuBarRingLimit.map { max(1, $0) }
    }

    public var menuBarProfiles: [Profile] {
        Array(profiles.prefix(menuBarRingLimit ?? profiles.count))
    }

    public mutating func setMenuBarRingLimit(_ count: Int) {
        menuBarRingLimit = min(max(1, profiles.count), max(1, count))
    }

    public mutating func moveProfile(_ id: String, by offset: Int) {
        guard let source = profiles.firstIndex(where: { $0.id == id }),
              offset == -1 || offset == 1 else { return }
        let destination = source + offset
        guard profiles.indices.contains(destination) else { return }
        profiles.swapAt(source, destination)
    }

    public mutating func setAutoHideDelay(_ seconds: Int) {
        autoHideDelaySeconds = min(300, max(1, seconds))
    }

    private enum CodingKeys: String, CodingKey {
        case profiles, autoConnectLocal, autoHideEnabled, autoHideDelaySeconds, menuBarRingLimit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let saved = try container.decode([Profile].self, forKey: .profiles)
        profiles = saved.filter { $0.kind != .legacyDemo }
        autoConnectLocal = try container.decodeIfPresent(Bool.self, forKey: .autoConnectLocal) ?? profiles.isEmpty
        autoHideEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoHideEnabled) ?? true
        let seconds = try container.decodeIfPresent(Int.self, forKey: .autoHideDelaySeconds) ?? 3
        autoHideDelaySeconds = min(300, max(1, seconds))
        menuBarRingLimit = (try? container.decodeIfPresent(Int.self, forKey: .menuBarRingLimit)).map { max(1, $0) }
    }
}

public enum ClientError: LocalizedError {
    case unavailable, notLoggedIn, unsupportedAccount, timeout, stopped, protocolError, server(String)
    public var errorDescription: String? {
        switch self {
        case .unavailable: return "未找到 Codex CLI。请安装 Codex，或设置 CODEX_CLI_PATH 后重试。"
        case .notLoggedIn: return "账户尚未登录，请完成登录后重试。"
        case .unsupportedAccount: return "此账户使用 API Key，无法读取订阅额度。请使用 ChatGPT 账户登录。"
        case .timeout: return "读取超时，请检查网络后重试。"
        case .stopped: return "Codex 连接已断开，请重试。"
        case .protocolError: return "Codex 返回了无法识别的数据，请更新 Codex 后重试。"
        case .server(let message): return "Codex：\(message)"
        }
    }
}
