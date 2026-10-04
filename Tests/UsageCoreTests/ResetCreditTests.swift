import Foundation
import Testing
@testable import UsageCore

private func usage(_ summary: String) throws -> AccountUsage {
    let json = "{\"rateLimits\":{},\"rateLimitResetCredits\":\(summary)}"
    return try #require(JSONDecoder().decode(RateResponse.self, from: Data(json.utf8)).usage)
}

@Test func resetExpirationsKeepAuthoritativeCountAndGroupAvailableDetails() throws {
    let value = try usage(#"""
    {"availableCount":7,"credits":[
        {"id":"late","status":"available","expiresAt":1900000000},
        {"id":"early","status":"available","expiresAt":1800000000},
        {"id":"same-time","status":"available","expiresAt":1800000000},
        {"id":"early","status":"available","expiresAt":1800000000},
        {"id":"never","status":"available","expiresAt":null},
        {"id":"missing-date","status":"available"},
        {"id":"redeemed","status":"redeemed","expiresAt":1700000000},
        {"id":"pending","status":"redeeming","expiresAt":1700000000},
        {"id":"unknown-status","status":"new-status","expiresAt":1700000000}
    ]}
    """#)
    #expect(value.bankedResetCount == 7)
    #expect(value.resetExpirationGroups == [
        ResetExpirationGroup(expiration: .at(Date(timeIntervalSince1970: 1800000000)), count: 2),
        ResetExpirationGroup(expiration: .at(Date(timeIntervalSince1970: 1900000000)), count: 1),
        ResetExpirationGroup(expiration: .never, count: 1),
        ResetExpirationGroup(expiration: .unknown, count: 3)
    ])
    let capped = try usage(#"{"availableCount":1,"credits":[{"id":"a","status":"available","expiresAt":null},{"id":"b","status":"available","expiresAt":null}]}"#)
    #expect(capped.resetExpirationGroups == [ResetExpirationGroup(expiration: .never, count: 1)])
}

@Test func incompleteResetDetailsNeverInventExpiryOrLoseQuota() throws {
    for details in ["null", "[]", "{}", #"[{"status":"available"}]"#] {
        let value = try usage("{\"availableCount\":3,\"credits\":\(details)}")
        #expect(value.bankedResetCount == 3)
        #expect(value.resetExpirationGroups == [ResetExpirationGroup(expiration: .unknown, count: 3)])
    }
    for expires in ["0", "-1", "253402300800", #""not-a-date""#] {
        let value = try usage("{\"availableCount\":1,\"credits\":[{\"id\":\"a\",\"status\":\"available\",\"expiresAt\":\(expires)}]}")
        #expect(value.resetExpirationGroups.first?.expiration == .unknown)
    }
    for count in ["0", "null", "-1"] {
        #expect(try usage("{\"availableCount\":\(count),\"credits\":[]}").resetExpirationGroups.isEmpty)
    }
    #expect(try usage("{\"availableCount\":\(Int.max)}").resetExpirationGroups.first?.count == Int.max)
}

@Test func resetExpirationUsesLocalCalendarAndDistinguishesPastNeverUnknown() throws {
    let date = Date(timeIntervalSince1970: 1800000000)
    let utc = try #require(TimeZone(secondsFromGMT: 0))
    let newYork = try #require(TimeZone(identifier: "America/New_York"))
    let expiration = ResetExpiration.at(date)
    let before = date.addingTimeInterval(-1)
    #expect(expiration.description(now: before, timeZone: utc) != expiration.description(now: before, timeZone: newYork))
    #expect(expiration.description(now: date, timeZone: utc).contains("已到期，待同步"))
    #expect(!expiration.description(now: before, timeZone: utc).contains("已到期"))
    #expect(ResetExpiration.never.description() == "不过期")
    #expect(ResetExpiration.unknown.description() == "到期时间未知")
}

@Test func planNamesKeepTiersDistinct() {
    #expect(PlanDisplay.name("pro") == "Pro 200")
    #expect(PlanDisplay.name("prolite") == "Pro Lite")
    #expect(PlanDisplay.name("promax") == "Pro Max")
    #expect(PlanDisplay.name("plus") == "Plus")
    #expect(PlanDisplay.name("new_plan") == "New Plan")
    #expect(PlanDisplay.name(nil) == nil)
    #expect(PlanDisplay.name(" ") == nil)
}
