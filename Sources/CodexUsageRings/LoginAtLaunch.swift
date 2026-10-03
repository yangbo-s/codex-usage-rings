import Combine
import ServiceManagement

@MainActor
protocol LoginItemManaging {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() async throws
}

@MainActor
private struct SystemLoginItemService: LoginItemManaging {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() async throws { try await SMAppService.mainApp.unregister() }
}

@MainActor
final class LoginAtLaunch: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var changing = false
    @Published private(set) var error: String?
    private let service: LoginItemManaging

    init(service: LoginItemManaging? = nil) {
        let resolved = service ?? SystemLoginItemService()
        self.service = resolved
        status = resolved.status
    }

    var isOn: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }
    func refresh() { status = service.status }

    func setEnabled(_ enabled: Bool) async {
        guard !changing else { return }
        changing = true
        error = nil
        defer { changing = false; refresh() }
        do {
            if enabled, !isOn { try service.register() }
            if !enabled, isOn { try await service.unregister() }
        } catch {
            self.error = "未能更新登录启动设置：\(error.localizedDescription)"
        }
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
