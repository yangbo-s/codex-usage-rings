import ServiceManagement
import Testing
@testable import CodexUsageRings

@MainActor
final class FakeLoginItemService: LoginItemManaging {
    var status: SMAppService.Status = .notRegistered
    var approveImmediately = true
    var shouldFail = false
    var registrations = 0
    func register() throws {
        if shouldFail { throw Failure.denied }
        registrations += 1
        status = approveImmediately ? .enabled : .requiresApproval
    }
    func unregister() async throws {
        if shouldFail { throw Failure.denied }
        status = .notRegistered
    }
    enum Failure: Error { case denied }
}

@Test @MainActor func loginSettingDefaultsOffAndFollowsSystem() async {
    let service = FakeLoginItemService()
    let model = LoginAtLaunch(service: service)
    #expect(!model.isOn)
    #expect(service.registrations == 0)
    await model.setEnabled(true)
    #expect(model.status == .enabled)
    await model.setEnabled(true)
    #expect(service.registrations == 1)
    await model.setEnabled(false)
    #expect(!model.isOn)
}

@Test @MainActor func pendingApprovalAndFailuresAreNotReportedAsEnabled() async {
    let service = FakeLoginItemService()
    service.approveImmediately = false
    let model = LoginAtLaunch(service: service)
    await model.setEnabled(true)
    #expect(model.needsApproval)
    #expect(model.status != .enabled)
    await model.setEnabled(false)
    service.shouldFail = true
    await model.setEnabled(true)
    #expect(!model.isOn)
    #expect(model.error != nil)
    #expect(!model.changing)
}
