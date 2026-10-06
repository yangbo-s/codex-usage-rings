import Foundation

public struct CreditBalance: Codable, Equatable {
    public var hasCredits: Bool?
    public var unlimited: Bool?
    public var balance: String?

    public init(hasCredits: Bool?, unlimited: Bool? = false, balance: String?) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }

    private enum CodingKeys: String, CodingKey { case hasCredits, unlimited, balance }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hasCredits = try? values.decodeIfPresent(Bool.self, forKey: .hasCredits)
        unlimited = try? values.decodeIfPresent(Bool.self, forKey: .unlimited)
        balance = try values.decodeIfPresent(String.self, forKey: .balance)
    }

    public var amount: Decimal? {
        guard let balance,
              balance.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: balance, locale: Locale(identifier: "en_US_POSIX")),
              !value.isNaN, value >= 0 else { return nil }
        return value
    }

    public var isAvailable: Bool {
        if unlimited == true { return true }
        guard hasCredits == true else { return false }
        // The availability flag can be known even when the exact balance is absent.
        return balance == nil || amount.map { $0 > 0 } == true
    }

    public func formattedBalance(locale: Locale = .current) -> String {
        if unlimited == true { return "无限" }
        guard let amount else { return "—" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        if amount > 0 && amount < Decimal(1) / 100 {
            return "< \(formatter.string(from: NSDecimalNumber(string: "0.01")) ?? "0.01")"
        }
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "—"
    }
}
