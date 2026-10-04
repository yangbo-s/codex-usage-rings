import Foundation
import Testing
@testable import CodexUsageRings

@MainActor private final class ManualScheduler {
    var delays: [TimeInterval] = []
    var callbacks: [@MainActor () -> Void] = []
    var cancelled: Set<Int> = []

    func schedule(_ seconds: TimeInterval, _ action: @escaping @MainActor () -> Void) -> () -> Void {
        let index = callbacks.count
        delays.append(seconds)
        callbacks.append(action)
        return { self.cancelled.insert(index) }
    }
}

@Test @MainActor func leavingStartsOneDeadlineAndReturningInvalidatesIt() {
    let scheduler = ManualScheduler()
    var closes = 0
    let panel = PanelAutoHide(schedule: scheduler.schedule) { closes += 1 }
    panel.configure(enabled: true, seconds: 3)
    #expect(scheduler.callbacks.isEmpty)
    panel.shown(pointerInside: true)
    #expect(scheduler.callbacks.isEmpty)
    panel.pointerChanged(inside: false)
    panel.pointerChanged(inside: false)
    #expect(scheduler.delays == [3])
    panel.pointerChanged(inside: true)
    #expect(scheduler.cancelled == [0])
    scheduler.callbacks[0]() // Even an already-queued callback cannot close a re-entered panel.
    #expect(closes == 0)
    panel.pointerChanged(inside: false)
    scheduler.callbacks[1]()
    scheduler.callbacks[1]()
    #expect(closes == 1)
    panel.pointerChanged(inside: true)
    panel.pointerChanged(inside: false)
    #expect(scheduler.callbacks.count == 2)
}

@Test @MainActor func editingSettingsAndClosingCancelAutoHide() {
    let scheduler = ManualScheduler()
    var closes = 0
    let panel = PanelAutoHide(schedule: scheduler.schedule) { closes += 1 }
    panel.configure(enabled: true, seconds: 3)
    panel.shown(pointerInside: false)
    panel.editingChanged(true)
    scheduler.callbacks[0]()
    #expect(closes == 0)
    panel.editingChanged(false)
    #expect(scheduler.delays == [3, 3])
    panel.configure(enabled: true, seconds: 12)
    #expect(scheduler.delays == [3, 3, 12])
    panel.configure(enabled: true, seconds: 12)
    #expect(scheduler.callbacks.count == 3) // Usage refreshes do not extend the deadline.
    panel.configure(enabled: false, seconds: 12)
    scheduler.callbacks[2]()
    #expect(closes == 0)
    panel.configure(enabled: true, seconds: 12)
    panel.closed()
    scheduler.callbacks[3]()
    #expect(closes == 0)
    #expect(scheduler.cancelled == [0, 1, 2, 3])
    panel.shown(pointerInside: false)
    scheduler.callbacks[4]()
    #expect(closes == 1)
}

@Test @MainActor func autoHidePreferencesPersistWithoutChangingAccounts() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = UsageStore(dataDirectory: directory)
    store.setAutoHide(enabled: false, delay: 18)
    let reopened = UsageStore(dataDirectory: directory)
    #expect(!reopened.settings.autoHideEnabled)
    #expect(reopened.settings.autoHideDelaySeconds == 18)
    #expect(reopened.visibleProfiles.isEmpty)
}
