import Foundation

/// Event driven: at most one one-shot timer, and none while the panel is hidden.
@MainActor
final class PanelAutoHide {
    typealias Scheduler = (TimeInterval, @escaping @MainActor () -> Void) -> () -> Void
    private let schedule: Scheduler
    private let dismiss: () -> Void
    private var cancel: (() -> Void)?
    private var generation = 0
    private var visible = false
    private var pointerInside = false
    private var editing = false
    private var delay: TimeInterval?

    init(schedule: Scheduler? = nil, dismiss: @escaping () -> Void) {
        self.schedule = schedule ?? { seconds, action in
            let timer = Timer(timeInterval: seconds, repeats: false) { _ in
                Task { @MainActor in action() }
            }
            timer.tolerance = min(0.1, seconds * 0.05)
            RunLoop.main.add(timer, forMode: .common)
            return { timer.invalidate() }
        }
        self.dismiss = dismiss
    }

    func configure(enabled: Bool, seconds: Int) {
        let next: TimeInterval? = enabled ? TimeInterval(min(300, max(1, seconds))) : nil
        guard next != delay else { return }
        delay = next
        reschedule()
    }

    func shown(pointerInside: Bool) {
        visible = true
        self.pointerInside = pointerInside
        reschedule()
    }

    func pointerChanged(inside: Bool) {
        guard inside != pointerInside else { return }
        pointerInside = inside
        reschedule()
    }

    func editingChanged(_ value: Bool) {
        guard value != editing else { return }
        editing = value
        reschedule()
    }

    func closed() {
        visible = false
        editing = false
        invalidate()
    }

    private func invalidate() {
        generation += 1
        cancel?()
        cancel = nil
    }

    private func reschedule() {
        invalidate()
        guard visible, !pointerInside, !editing, let delay else { return }
        let current = generation
        cancel = schedule(delay) { [weak self] in
            guard let self, self.generation == current else { return }
            self.closed()
            self.dismiss()
        }
    }
}
