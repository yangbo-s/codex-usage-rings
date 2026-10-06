import Foundation
import Testing
@testable import UsageCore

@Test func creditBalancesPreservePrecisionAndUnknownValues() throws {
    let locale = Locale(identifier: "en_US")
    for (raw, formatted) in [("12345.6789000000", "12,345.68"), ("0", "0"), ("0.001", "< 0.01"),
                             ("12.5", "12.5"), ("-1", "—"), ("NaN", "—"), ("123junk", "—"), ("", "—")] {
        let credits = CreditBalance(hasCredits: true, balance: raw)
        #expect(credits.formattedBalance(locale: locale) == formatted)
    }
    let value = CreditBalance(hasCredits: true, balance: "12345.6789000000")
    #expect(value.amount == Decimal(string: "12345.6789000000"))
    #expect(try JSONDecoder().decode(CreditBalance.self, from: JSONEncoder().encode(value)) == value)
    #expect(CreditBalance(hasCredits: nil, balance: nil).formattedBalance() == "—")
    #expect(CreditBalance(hasCredits: true, unlimited: true, balance: nil).formattedBalance() == "无限")
    #expect(!CreditBalance(hasCredits: false, balance: "100").isAvailable)
    #expect(!CreditBalance(hasCredits: true, balance: "0").isAvailable)
}

@Test func creditDecodingKeepsQuotaForOldAndMalformedResponses() throws {
    for payload in ["null", "[]", #"{"balance":12,"hasCredits":true}"#, #"{"balance":"bad","hasCredits":true}"#] {
        let json = "{\"rateLimits\":{\"primary\":{\"usedPercent\":100},\"credits\":\(payload)}}"
        let usage = try #require(JSONDecoder().decode(RateResponse.self, from: Data(json.utf8)).usage)
        #expect(usage.rings.percentage == "0%")
        #expect(usage.limits.credits?.formattedBalance() ?? "—" == "—")
        #expect(!usage.usesCreditFallback)
    }
    let json = #"{"ordinaryUsageAllowed":false,"rateLimits":{"credits":{"hasCredits":false,"balance":"0"}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":100,"windowDurationMins":10080},"credits":{"hasCredits":true,"unlimited":false,"balance":"100.25"}}}}"#
    let usage = try #require(JSONDecoder().decode(RateResponse.self, from: Data(json.utf8)).usage)
    #expect(usage.limits.credits?.balance == "100.25")
    #expect(usage.rings.number == "C")
    #expect(usage.rings.percentage == "0%")
}

@Test func creditFallbackRequiresExhaustionAndAvailableCredits() {
    let available = CreditBalance(hasCredits: true, balance: "25")
    func usage(_ used: Double?, credits: CreditBalance? = nil) -> AccountUsage {
        AccountUsage(limits: RateSnapshot(primary: UsageWindow(usedPercent: used, windowDurationMins: 10080, resetsAt: nil),
                                         secondary: nil, credits: credits), bankedResetCount: 0)
    }
    #expect(usage(100, credits: available).rings.number == "C")
    #expect(usage(100, credits: CreditBalance(hasCredits: true, unlimited: true, balance: nil)).usesCreditFallback)
    #expect(!usage(99.9, credits: available).usesCreditFallback) // Rounded 0 is not actual exhaustion.
    #expect(!usage(nil, credits: available).usesCreditFallback)
    #expect(!usage(100).usesCreditFallback)
    #expect(!usage(100, credits: CreditBalance(hasCredits: true, balance: "0")).usesCreditFallback)
    #expect(usage(100, credits: CreditBalance(hasCredits: false, balance: "0")).rings.number == "0")
    #expect(usage(34, credits: available).rings.number == "66")
    var nested = usage(34, credits: available)
    nested.limits.secondary = UsageWindow(usedPercent: 100, windowDurationMins: 300, resetsAt: nil)
    #expect(nested.rings.number == "C")
    #expect(nested.rings.outer?.remaining == 66)
    #expect(nested.rings.inner?.remaining == 0)
}

@Test func menuBarSelectionMigratesReordersAndKeepsAnEntry() throws {
    let profiles = ["a", "b", "c"].map { Profile(id: $0, name: $0, kind: .managed) }
    let old = #"{"profiles":[{"id":"a","name":"A","kind":"local"},{"id":"b","name":"B","kind":"managed"}]}"#
    #expect(try JSONDecoder().decode(Settings.self, from: Data(old.utf8)).menuBarProfiles.count == 2)
    var settings = Settings(profiles: profiles)
    #expect(settings.menuBarProfiles.map(\.id) == ["a", "b", "c"])
    settings.setMenuBarRingLimit(2)
    settings.moveProfile("c", by: -1)
    settings.moveProfile("c", by: -1)
    #expect(settings.menuBarProfiles.map(\.id) == ["c", "a"])
    #expect(settings.profiles.map(\.id) == ["c", "a", "b"])
    settings.moveProfile("c", by: -1)
    settings.moveProfile("b", by: 1)
    settings.moveProfile("missing", by: -1)
    settings.moveProfile("a", by: Int.max)
    #expect(settings.profiles.map(\.id) == ["c", "a", "b"])
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)) == settings)
    settings.setMenuBarRingLimit(0)
    #expect(settings.menuBarProfiles.map(\.id) == ["c"])
    settings.profiles.removeFirst()
    #expect(settings.menuBarProfiles.map(\.id) == ["a"])
    settings.profiles = [profiles[2]]
    #expect(settings.menuBarProfiles.map(\.id) == ["c"])
    settings.profiles = []
    #expect(settings.menuBarProfiles.isEmpty)
    #expect(Settings(profiles: profiles, menuBarRingLimit: Int.max).menuBarProfiles.count == 3)
}
