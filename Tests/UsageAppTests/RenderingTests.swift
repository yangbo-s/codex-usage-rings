import AppKit
import SwiftUI
import Testing
import UsageCore
@testable import CodexUsageRings

@Test @MainActor func ringGeometryFitsNumbersAndCountsEveryReset() async throws {
    _ = NSApplication.shared
    func window(_ used: Double, _ minutes: Int) -> UsageWindow {
        UsageWindow(usedPercent: used, windowDurationMins: minutes, resetsAt: nil)
    }
    let variants: [(String, RingPresentation)] = [
        ("单环 · 64% · 0 reset", AccountUsage(limits: RateSnapshot(primary: window(36, 10080), secondary: nil), bankedResetCount: 0).rings),
        ("双环 · 周 64% / 5h 28% · 2 reset", AccountUsage(limits: RateSnapshot(primary: window(72, 300), secondary: window(36, 10080)), bankedResetCount: 2).rings),
        ("单环 · 100% · 3 reset", AccountUsage(limits: RateSnapshot(primary: window(0, 10080), secondary: nil), bankedResetCount: 3).rings),
        ("双环 · 100% / 5h 100%", AccountUsage(limits: RateSnapshot(primary: window(0, 300), secondary: window(0, 10080)), bankedResetCount: 0).rings),
        ("已用完 · 0%", AccountUsage(limits: RateSnapshot(primary: window(100, 10080), secondary: nil), bankedResetCount: 0).rings),
        ("未连接 · 未知额度", RingPresentation())
    ]
    for (_, rings) in variants {
        let image = RingRenderer.image(rings)
        let expected = CGFloat((rings.bankedResetCount ?? 0) > 0 ? 3 + (rings.bankedResetCount ?? 0) * 3 : 0)
        #expect(image.size.width == 20 + expected)
        #expect(image.size.height == 20)
        let hole: CGFloat = rings.isNested ? 7 - 0.575 : 10 - 2.2 - 0.6
        #expect(!rings.number.contains("%"))
        let attributes = RingRenderer.textAttributes(for: rings.number, holeRadius: hole, scale: 1)
        let size = (rings.number as NSString).size(withAttributes: attributes)
        #expect(hypot(size.width, size.height) <= hole * 2 - 0.5)
    }
    // Only tests carry synthetic examples; the application has no preview/demo mode.
    guard let output = ProcessInfo.processInfo.environment["USAGE_RINGS_SNAPSHOT_DIR"] else { return }
    let directory = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let (fixtureDirectory, executable) = try fixture("""
    for line in sys.stdin:
        r = json.loads(line)
        if 'id' not in r: continue
        result = {}
        if r['method'] == 'account/read':
            result = {'account': {'type': 'chatgpt', 'planType': 'pro'}}
        if r['method'] == 'account/rateLimits/read':
            result = {'rateLimits': {'primary': {'usedPercent': 57, 'windowDurationMins': 10080, 'resetsAt': time.time() + 540000}}, 'rateLimitResetCredits': {'availableCount': 1}}
        print(json.dumps({'id': r['id'], 'result': result}), flush=True)
    """)
    defer { try? FileManager.default.removeItem(at: fixtureDirectory) }
    let store = UsageStore(dataDirectory: fixtureDirectory.appendingPathComponent("data"), clientFactory: {
        CodexClient(home: $0, executable: executable)
    })
    await store.connectLocal()
    defer { store.stop() }
    for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
        let drawingAppearance = try #require(NSAppearance(named: appearance))
        NSApp.appearance = drawingAppearance
        let board = NSImage(size: NSSize(width: 600, height: 420), flipped: true) { rect in
            drawingAppearance.performAsCurrentDrawingAppearance {
                NSColor.windowBackgroundColor.setFill(); rect.fill()
                let heading: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16, weight: .semibold), .foregroundColor: NSColor.labelColor]
                ("圆环绘制验证 · 测试输入" as NSString).draw(at: NSPoint(x: 24, y: 20), withAttributes: heading)
                for (index, variant) in variants.enumerated() {
                    let y = CGFloat(65 + index * 56)
                    let label: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor]
                    (variant.0 as NSString).draw(at: NSPoint(x: 24, y: y + 6), withAttributes: label)
                    let actual = RingRenderer.image(variant.1)
                    actual.draw(in: NSRect(x: 306, y: y + 3, width: actual.size.width, height: 20), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                    let enlarged = RingRenderer.image(variant.1, diameter: 36)
                    enlarged.draw(in: NSRect(x: 422, y: y - 6, width: enlarged.size.width, height: 36), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                }
            }
            return true
        }
        try save(board, to: directory.appendingPathComponent("rings-\(name).png"))
        store.managing = false
        try savePanel(store, height: 335, appearance: appearance, to: directory.appendingPathComponent("overview-\(name).png"))
        store.managing = true
        try savePanel(store, height: 560, appearance: appearance, to: directory.appendingPathComponent("settings-\(name).png"))
    }
}

@MainActor private func savePanel(_ store: UsageStore, height: CGFloat, appearance: NSAppearance.Name, to url: URL) throws {
    let panel = NSHostingView(rootView: UsagePanel(store: store, loginAtLaunch: LoginAtLaunch(service: FakeLoginItemService())))
    panel.frame = NSRect(x: 0, y: 0, width: 360, height: height)
    panel.appearance = NSAppearance(named: appearance)
    let window = NSWindow(contentRect: panel.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = panel
    panel.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    let bitmap = try #require(panel.bitmapImageRepForCachingDisplay(in: panel.bounds))
    panel.cacheDisplay(in: panel.bounds, to: bitmap)
    let png = try #require(bitmap.representation(using: .png, properties: [:]))
    try png.write(to: url)
}

@MainActor private func save(_ image: NSImage, to url: URL) throws {
    let tiff = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiff))
    let png = try #require(bitmap.representation(using: .png, properties: [:]))
    try png.write(to: url)
}
