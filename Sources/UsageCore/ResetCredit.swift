import Foundation

public enum ResetExpiration: Hashable {
    case at(Date), never, unknown

    public func description(now: Date = Date(), timeZone: TimeZone = .autoupdatingCurrent) -> String {
        switch self {
        case .at(let date):
            let style = Date.FormatStyle(date: .numeric, time: .shortened,
                                        locale: Locale(identifier: "zh_CN"), timeZone: timeZone)
            return "\(date.formatted(style)) \(date <= now ? "已到期，待同步" : "到期")"
        case .never: return "不过期"
        case .unknown: return "到期时间未知"
        }
    }
}

public struct ResetCredit: Decodable, Equatable {
    public var id: String
    public var status: String
    public var expiration: ResetExpiration

    private enum CodingKeys: String, CodingKey { case id, status, expiresAt }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = (try? container.decode(String.self, forKey: .status)) ?? "unknown"
        if !container.contains(.expiresAt) {
            expiration = .unknown
        } else if try container.decodeNil(forKey: .expiresAt) {
            // The protocol explicitly defines null as a non-expiring credit.
            expiration = .never
        } else if let seconds = try? container.decode(Double.self, forKey: .expiresAt),
                  seconds.isFinite, seconds > 0, seconds < 253_402_300_800 {
            expiration = .at(Date(timeIntervalSince1970: seconds))
        } else {
            expiration = .unknown
        }
    }
}

public struct ResetExpirationGroup: Equatable, Identifiable {
    public var expiration: ResetExpiration
    public var count: Int
    public var id: ResetExpiration { expiration }
}

extension AccountUsage {
    public var resetExpirationGroups: [ResetExpirationGroup] {
        guard let count = bankedResetCount, count > 0 else { return [] }
        var seen = Set<String>()
        var grouped: [ResetExpiration: Int] = [:]
        var listed = 0
        for credit in resetCredits ?? [] {
            guard listed < count else { break }
            guard credit.status == "available", seen.insert(credit.id).inserted else { continue }
            grouped[credit.expiration, default: 0] += 1
            listed += 1
        }
        if listed < count { grouped[.unknown, default: 0] += count - listed }
        return grouped.map { ResetExpirationGroup(expiration: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                switch (lhs.expiration, rhs.expiration) {
                case (.at(let a), .at(let b)): return a < b
                case (.at, _), (.never, .unknown): return true
                default: return false
                }
            }
    }
}
