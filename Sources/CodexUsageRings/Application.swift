import AppKit
import Combine
import SwiftUI
import UsageCore

@main
struct UsageRingsMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--probe") {
            Task {
                let client = CodexClient(home: nil)
                do {
                    let account = try await client.account()
                    let usage = try await client.usage()
                    print("accountType=\(account.type) plan=\(account.planType ?? "unknown") primaryRemaining=\(usage.limits.primary?.percentage ?? "unknown") secondaryRemaining=\(usage.limits.secondary?.percentage ?? "unknown") primaryMinutes=\(usage.limits.primary?.windowDurationMins.map(String.init) ?? "unknown") secondaryMinutes=\(usage.limits.secondary?.windowDurationMins.map(String.init) ?? "unknown") bankedResets=\(usage.bankedResetCount.map(String.init) ?? "unknown")")
                    let timed = usage.resetExpirationGroups.reduce(0) { count, group in
                        if case .at = group.expiration { return count + group.count }
                        return count
                    }
                    print("resetExpiryKnown=\(timed) nonExpiring=\(usage.resetExpirationGroups.first(where: { $0.expiration == .never })?.count ?? 0) expiryUnknown=\(usage.resetExpirationGroups.first(where: { $0.expiration == .unknown })?.count ?? 0)")
                    print("creditBalanceKnown=\(usage.limits.credits?.amount != nil) creditAvailable=\(usage.limits.credits?.isAvailable == true) ringLabel=\(usage.rings.number)")
                    client.stop()
                    exit(0)
                } catch {
                    print("Read-only probe failed: \(error.localizedDescription)")
                    client.stop()
                    exit(1)
                }
            }
            RunLoop.main.run()
            return
        }
        let app = NSApplication.shared
        let delegate = ApplicationDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = UsageStore()
        controller = MenuBarController(store: store)
        store.start()
        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.controller?.showFirst() }
        }
    }
    func applicationWillTerminate(_ notification: Notification) { controller?.stop() }
}

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let store: UsageStore
    private let loginAtLaunch = LoginAtLaunch()
    private var items: [String: NSStatusItem] = [:]
    private var itemOrder: [String] = []
    private let popover = NSPopover()
    private var observation: AnyCancellable?
    private lazy var autoHide = PanelAutoHide { [weak self] in self?.close() }

    init(store: UsageStore) {
        self.store = store
        super.init()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: UsagePanel(
            store: store, loginAtLaunch: loginAtLaunch,
            onHover: { [weak self] inside in self?.autoHide.pointerChanged(inside: inside) },
            onEditing: { [weak self] editing in self?.autoHide.editingChanged(editing) }
        ))
        observation = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateItems() }
        }
        updateItems()
    }

    private func updateItems() {
        autoHide.configure(enabled: store.settings.autoHideEnabled, seconds: store.settings.autoHideDelaySeconds)
        let profiles = store.menuBarProfiles
        let desired = profiles.isEmpty ? ["launcher"] : profiles.map(\.id)
        if desired != itemOrder {
            let reopen = popover.isShown
            // Replacing an anchor is structural; close immediately before removing its view.
            autoHide.closed()
            popover.close()
            items.values.forEach { NSStatusBar.system.removeStatusItem($0) }
            items.removeAll()
            // Status items are inserted from right to left; create in reverse to preserve list order.
            for id in desired.reversed() {
                let item = NSStatusBar.system.statusItem(withLength: 30)
                item.button?.target = self
                item.button?.action = #selector(clicked(_:))
                items[id] = item
            }
            itemOrder = desired
            if reopen { DispatchQueue.main.async { [weak self] in self?.showFirst() } }
        }
        for id in desired {
            guard let button = items[id]?.button else { continue }
            if let profile = profiles.first(where: { $0.id == id }) {
                let state = store.states[id] ?? AccountState()
                button.image = RingRenderer.image(state.rings, stale: state.isStale)
                let limits = [state.rings.outer, state.rings.inner].compactMap { $0 }
                    .map { "\($0.title) 剩余 \($0.percentage)" }.joined(separator: " · ")
                let resets = state.usage?.bankedResetCount.map { "Banked reset \($0) 次" } ?? "Banked reset 未知"
                let stale = state.isStale ? " · 数据已过期" : ""
                let creditStatus = state.rings.usesCredits ? " · \(state.rings.accessibilitySummary)" : ""
                button.toolTip = "\(profile.name) · \(limits.isEmpty ? "等待同步" : limits)\(creditStatus) · \(resets)\(stale)"
            } else {
                button.image = RingRenderer.image(RingPresentation())
                button.toolTip = "Usage Rings · 点击连接账户"
            }
            items[id]?.length = button.image?.size.width ?? RingRenderer.menuDiameter
            button.imageScaling = .scaleProportionallyDown
            button.setAccessibilityLabel(button.toolTip)
        }
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard let id = items.first(where: { $0.value.button === sender })?.key else { return }
        if popover.isShown, (store.selectedID == id || id == "launcher") { close(); return }
        store.selectedID = id == "launcher" ? store.visibleProfiles.first?.id : id
        store.managing = id == "launcher"
        show(relativeTo: sender)
    }

    private func show(relativeTo button: NSStatusBarButton) {
        loginAtLaunch.refresh()
        Task { await store.refreshAll(minimumAge: 60) }
        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let repositioning = popover.isShown
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        if repositioning { updatePointerAfterShowing() }
    }

    private func close() {
        autoHide.closed()
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.performClose(nil)
    }

    private func updatePointerAfterShowing() {
        guard popover.isShown else { return }
        let inside = popover.contentViewController?.view.window?.frame.contains(NSEvent.mouseLocation) ?? false
        autoHide.shown(pointerInside: inside)
    }

    func popoverDidShow(_ notification: Notification) { updatePointerAfterShowing() }
    func popoverWillClose(_ notification: Notification) { autoHide.closed() }

    func showFirst() {
        if let first = itemOrder.first, let button = items[first]?.button { show(relativeTo: button) }
    }

    func stop() { autoHide.closed(); store.stop() }
}
