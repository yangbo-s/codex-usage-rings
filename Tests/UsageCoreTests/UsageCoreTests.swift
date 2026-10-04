import Foundation
import Testing
@testable import UsageCore

@Test func remainingPercentHandlesBoundariesAndUnknown() {
    func window(_ used: Double?) -> UsageWindow {
        UsageWindow(usedPercent: used, windowDurationMins: 300, resetsAt: nil)
    }
    #expect(window(28).remaining == 72)
    #expect(window(0).remaining == 100)
    #expect(window(100).remaining == 0)
    #expect(window(120).remaining == 0)
    #expect(window(-10).remaining == 100)
    #expect(window(nil).remaining == nil)
    #expect(window(.nan).remaining == nil)
    #expect(window(.infinity).remaining == nil)
    #expect(window(nil).percentage == "—")
}

@Test func decodesLegacyAndPrefersCodexBucket() throws {
    let json = #"{"rateLimits":{"primary":{"usedPercent":40,"windowDurationMins":300,"resetsAt":1800000000}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":25},"secondary":null},"other":{"primary":{"usedPercent":90}}}}"#
    let response = try JSONDecoder().decode(RateResponse.self, from: Data(json.utf8))
    #expect(response.codex?.primary?.remaining == 75)
    #expect(response.codex?.secondary == nil)
    #expect(response.codex?.primary?.windowDurationMins == nil)
    let legacy = #"{"rateLimits":{"primary":{"usedPercent":40,"windowDurationMins":300,"resetsAt":1800000000}}}"#
    let old = try JSONDecoder().decode(RateResponse.self, from: Data(legacy.utf8))
    #expect(old.codex?.primary?.remaining == 60)
}

@Test func nullAndInvalidDataNeverBecomeFullQuota() throws {
    for json in [#"{"rateLimits":null}"#, #"{}"#, #"{"rateLimits":{"primary":null}}"#] {
        let response = try JSONDecoder().decode(RateResponse.self, from: Data(json.utf8))
        #expect(response.codex?.primary?.remaining == nil)
    }
    let invalid = #"{"rateLimits":{"primary":{"usedPercent":"unknown"}}}"#
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(RateResponse.self, from: Data(invalid.utf8))
    }
}

@Test func resetTimesNeverShowNegativeOrFalseReset() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func description(_ offset: Double?) -> String {
        UsageWindow(usedPercent: 10, windowDurationMins: 300,
                    resetsAt: offset.map { now.timeIntervalSince1970 + $0 }).resetDescription(now: now)
    }
    #expect(description(nil) == "重置时间未知")
    #expect(description(-1) == "等待额度更新")
    #expect(description(0) == "等待额度更新")
    #expect(description(1) == "1 分钟后重置")
    #expect(description(7_920) == "2 小时 12 分钟后重置")
    #expect(description(259_200) == "3 天 0 小时后重置")
}

@Test func labelsUseActualWindowDuration() {
    #expect(UsageWindow(usedPercent: 0, windowDurationMins: 300, resetsAt: nil).title == "5 小时额度")
    #expect(UsageWindow(usedPercent: 0, windowDurationMins: 10_080, resetsAt: nil).title == "每周额度")
    #expect(UsageWindow(usedPercent: 0, windowDurationMins: 15, resetsAt: nil).title == "15 分钟额度")
    #expect(UsageWindow(usedPercent: 0, windowDurationMins: nil, resetsAt: nil).title == "额度窗口")
}

@Test func settingsRoundTripPreservesRealAccounts() throws {
    let settings = Settings(profiles: [
        Profile(id: "a", name: "个人账户", kind: .managed),
        Profile(id: "b", name: "工作账户", kind: .local)
    ], autoConnectLocal: false)
    let encoded = try JSONEncoder().encode(settings)
    #expect(try JSONDecoder().decode(Settings.self, from: encoded) == settings)
    #expect(!String(decoding: encoded, as: UTF8.self).contains("token"))
}

@Test func autoHideSettingsMigrateAndClampWithoutLosingAccounts() throws {
    let old = #"{"profiles":[{"id":"real","name":"个人","kind":"local"}],"autoConnectLocal":false}"#
    let migrated = try JSONDecoder().decode(Settings.self, from: Data(old.utf8))
    #expect(migrated.profiles.map(\.id) == ["real"])
    #expect(migrated.autoHideEnabled)
    #expect(migrated.autoHideDelaySeconds == 3)
    for (input, expected) in [(0, 1), (-50, 1), (25, 25), (999, 300)] {
        let json = "{\"profiles\":[],\"autoHideDelaySeconds\":\(input),\"autoHideEnabled\":false}"
        var settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        #expect(settings.autoHideDelaySeconds == expected)
        #expect(!settings.autoHideEnabled)
        settings.setAutoHideDelay(input)
        #expect(settings.autoHideDelaySeconds == expected)
        #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)) == settings)
    }
}

@Test func ringNumbersKeepUnitsInAccessiblePercentage() {
    for (used, number, percentage) in [(0.0, "100", "100%"), (100.0, "0", "0%"), (56.6, "43", "43%")] {
        let rings = AccountUsage(limits: RateSnapshot(primary: UsageWindow(usedPercent: used, windowDurationMins: 10080, resetsAt: nil), secondary: nil), bankedResetCount: nil).rings
        #expect(rings.number == number)
        #expect(rings.percentage == percentage)
    }
    #expect(RingPresentation().number == "—")
}

@Test func migratesPreviewSettingsWithoutLosingRealAccounts() throws {
    let old = #"{"showDemo":true,"profiles":[{"id":"demo-personal","name":"个人账户","kind":"demo","isPinned":true,"window":"primary"},{"id":"real","name":"我的账号","kind":"managed","isPinned":false,"window":"secondary"}]}"#
    let settings = try JSONDecoder().decode(Settings.self, from: Data(old.utf8))
    #expect(settings.profiles.map(\.id) == ["real"])
    #expect(settings.profiles.first?.name == "我的账号")
    #expect(!settings.autoConnectLocal)
    let encoded = String(decoding: try JSONEncoder().encode(settings), as: UTF8.self)
    #expect(!encoded.contains("demo"))
    #expect(!encoded.contains("showDemo"))
    #expect(Settings().profiles.isEmpty)
}

@Test func nestedRingsFollowDurationNotPosition() {
    let weekly = UsageWindow(usedPercent: 30, windowDurationMins: 10_080, resetsAt: nil)
    let fiveHour = UsageWindow(usedPercent: 80, windowDurationMins: 300, resetsAt: nil)
    for limits in [RateSnapshot(primary: fiveHour, secondary: weekly), RateSnapshot(primary: weekly, secondary: fiveHour)] {
        let rings = AccountUsage(limits: limits, bankedResetCount: 2).rings
        #expect(rings.outer == weekly)
        #expect(rings.inner == fiveHour)
        #expect(rings.percentage == "70%")
        #expect(rings.isNested)
    }
    let single = AccountUsage(limits: RateSnapshot(primary: weekly, secondary: nil), bankedResetCount: 0).rings
    #expect(!single.isNested)
    #expect(single.percentage == "70%")
    let onlyFive = AccountUsage(limits: RateSnapshot(primary: fiveHour, secondary: nil), bankedResetCount: nil).rings
    #expect(!onlyFive.isNested)
    #expect(onlyFive.outer == fiveHour)
}

@Test func unknownWindowIsNotInventedAsFiveHours() {
    let unknown = UsageWindow(usedPercent: nil, windowDurationMins: nil, resetsAt: nil)
    let weekly = UsageWindow(usedPercent: 20, windowDurationMins: 10_080, resetsAt: nil)
    let rings = AccountUsage(limits: RateSnapshot(primary: unknown, secondary: weekly), bankedResetCount: nil).rings
    #expect(rings.outer == weekly)
    #expect(!rings.isNested)
    #expect(RingPresentation().percentage == "—")
}

@Test func bankedResetCountIsAuthoritativeAndOptional() throws {
    for (payload, expected) in [
        (#"{"availableCount":3,"credits":[]}"#, Optional(3)),
        (#"{"availableCount":0,"credits":null}"#, Optional(0)),
        (#"{"availableCount":null}"#, nil),
        (#"{"availableCount":-1}"#, nil),
        ("null", nil)
    ] {
        let json = "{\"rateLimits\":{},\"rateLimitResetCredits\":\(payload)}"
        let response = try JSONDecoder().decode(RateResponse.self, from: Data(json.utf8))
        #expect(response.usage?.bankedResetCount == expected)
    }
    let missing = try JSONDecoder().decode(RateResponse.self, from: Data(#"{"rateLimits":{}}"#.utf8))
    #expect(missing.usage?.bankedResetCount == nil)
}

@Test func powerPolicyCoalescesAndBacksOff() {
    #expect(RefreshPolicy.interval(lowPower: false) == 300)
    #expect(RefreshPolicy.interval(lowPower: true) == 900)
    #expect(RefreshPolicy.tolerance(lowPower: false) == 60)
    #expect(RefreshPolicy.tolerance(lowPower: true) == 180)
    #expect([1, 2, 3, 4, 5, 100].map { RefreshPolicy.failureDelay(attempt: $0) } == [300, 600, 1200, 2400, 3600, 3600])
    let now = Date()
    #expect(!RefreshPolicy.shouldRefresh(lastUpdate: now.addingTimeInterval(-30), nextRetry: nil, now: now, minimumAge: 60, force: false))
    #expect(!RefreshPolicy.shouldRefresh(lastUpdate: nil, nextRetry: now.addingTimeInterval(200), now: now, minimumAge: 0, force: false))
    #expect(RefreshPolicy.shouldRefresh(lastUpdate: now, nextRetry: now.addingTimeInterval(200), now: now, minimumAge: 60, force: true))
    #expect(RefreshPolicy.shouldRefresh(lastUpdate: now.addingTimeInterval(-60), nextRetry: nil, now: now, minimumAge: 60, force: false))
}
