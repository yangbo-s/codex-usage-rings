import Foundation

public enum ResetExpiration: Hashable {
    case at(Date), never, unknown

    public func description(now: Date = Date(), timeZone: TimeZone = .autoupdatingCurrent) -> String {
        switch self {
        case .at(let date):
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = timeZone
            formatter.dateFormat = sameYear ? "MMMM d, HH:mm" : "MMMM d, yyyy, HH:mm"
            return "\(date <= now ? "Expired" : "Expires") \(formatter.string(from: date))"
        case .never: return "No expiry"
        case .unknown: return "Expiry unknown"
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
    public var availableResetCredits: [ResetCredit] {
        guard let count = bankedResetCount, count > 0 else { return [] }
        var seen = Set<String>()
        var available: [ResetCredit] = []
        for credit in resetCredits ?? [] {
            guard available.count < count else { break }
            guard credit.status == "available", seen.insert(credit.id).inserted else { continue }
            available.append(credit)
        }
        return available.sorted { lhs, rhs in
            if lhs.expiration == rhs.expiration { return lhs.id < rhs.id }
            return Self.expirationPrecedes(lhs.expiration, rhs.expiration)
        }
    }

    public var unlistedResetCount: Int? {
        bankedResetCount.map { max(0, $0 - availableResetCredits.count) }
    }

    // The diagnostic probe uses aggregate counts; the panel lists individual credits.
    public var resetExpirationGroups: [ResetExpirationGroup] {
        guard let count = bankedResetCount, count > 0 else { return [] }
        let available = availableResetCredits
        var grouped: [ResetExpiration: Int] = [:]
        for credit in available { grouped[credit.expiration, default: 0] += 1 }
        if available.count < count { grouped[.unknown, default: 0] += count - available.count }
        return grouped.map { ResetExpirationGroup(expiration: $0.key, count: $0.value) }
            .sorted { Self.expirationPrecedes($0.expiration, $1.expiration) }
    }

    private static func expirationPrecedes(_ lhs: ResetExpiration, _ rhs: ResetExpiration) -> Bool {
        switch (lhs, rhs) {
        case (.at(let a), .at(let b)): return a < b
        case (.at, _), (.never, .unknown): return true
        default: return false
        }
    }
}
