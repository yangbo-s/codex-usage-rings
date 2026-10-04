import AppKit
import SwiftUI
import Testing
import UsageCore
@testable import CodexUsageRings

@Test @MainActor func resetStrokesMatchOuterRingInRenderedPixels() throws {
    _ = NSApplication.shared
    let appearance = try #require(NSAppearance(named: .aqua))
    for nested in [false, true] {
        let outer = UsageWindow(usedPercent: 0, windowDurationMins: 10080, resetsAt: nil)
        let inner = UsageWindow(usedPercent: 90, windowDurationMins: 300, resetsAt: nil)
        let rings = AccountUsage(limits: RateSnapshot(primary: outer, secondary: nested ? inner : nil), bankedResetCount: 1).rings
        var tiff: Data?
        appearance.performAsCurrentDrawingAppearance {
            tiff = RingRenderer.image(rings, diameter: 90).tiffRepresentation
        }
        let data = try #require(tiff)
        let bitmap = try #require(NSBitmapImageRep(data: data))
        var runs: [Int] = []
        var width = 0
        for x in 0..<bitmap.pixelsWide {
            let color = try #require(bitmap.colorAt(x: x, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.deviceRGB))
            let green = color.alphaComponent > 0.5 && color.greenComponent > color.redComponent * 1.4 && color.greenComponent > color.blueComponent * 1.2
            if green { width += 1 }
            else if width > 0 { runs.append(width); width = 0 }
        }
        if width > 0 { runs.append(width) }
        #expect(runs.count == 3) // Outer circle on both sides, then one reset stroke.
        if runs.count == 3 {
            #expect(abs(runs[0] - runs[2]) <= 2)
            #expect(abs(runs[1] - runs[2]) <= 2)
        }
    }
}

@Test @MainActor func ringGeometryFitsNumbersAndCapsResetMarkers() async throws {
    _ = NSApplication.shared
    func window(_ used: Double, _ minutes: Int) -> UsageWindow {
        UsageWindow(usedPercent: used, windowDurationMins: minutes, resetsAt: nil)
    }
    let variants: [(String, RingPresentation)] = [
        ("绿 · 75% · 1 reset", AccountUsage(limits: RateSnapshot(primary: window(25, 10080), secondary: nil), bankedResetCount: 1).rings),
        ("蓝 · 50% · 1 reset", AccountUsage(limits: RateSnapshot(primary: window(50, 10080), secondary: nil), bankedResetCount: 1).rings),
        ("黄 · 25% · 1 reset", AccountUsage(limits: RateSnapshot(primary: window(75, 10080), secondary: nil), bankedResetCount: 1).rings),
        ("红 · 24% · 1 reset", AccountUsage(limits: RateSnapshot(primary: window(76, 10080), secondary: nil), bankedResetCount: 1).rings),
        ("双环 · 周 80% / 5h 12% · 2 reset", AccountUsage(limits: RateSnapshot(primary: window(88, 300), secondary: window(20, 10080)), bankedResetCount: 2).rings),
        ("单环 · 100% · 3 reset", AccountUsage(limits: RateSnapshot(primary: window(0, 10080), secondary: nil), bankedResetCount: 3).rings),
        ("双环 · 100% / 5h 100%", AccountUsage(limits: RateSnapshot(primary: window(0, 300), secondary: window(0, 10080)), bankedResetCount: 0).rings),
        ("已用完 · 0%", AccountUsage(limits: RateSnapshot(primary: window(100, 10080), secondary: nil), bankedResetCount: 0).rings),
        ("未连接 · 未知额度", RingPresentation())
    ]
    for (_, rings) in variants {
        let image = RingRenderer.image(rings)
        #expect(image.size.width <= 25.5)
        #expect(image.size.height == 18)
        let hole: CGFloat = rings.isNested ? 6.2 - 0.525 : 9 - 2 - 0.6
        #expect(!rings.number.contains("%"))
        let label = RingRenderer.labelLayout(rings.number, holeRadius: hole, scale: 1)
        #expect(hypot(label.bounds.width, label.bounds.height) <= hole * 2 - 0.6)
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
            result = {'rateLimits': {'primary': {'usedPercent': 57, 'windowDurationMins': 10080, 'resetsAt': time.time() + 540000}}, 'rateLimitResetCredits': {'availableCount': 4, 'credits': [
                {'id': 'a', 'status': 'available', 'expiresAt': 1793299440},
                {'id': 'b', 'status': 'available', 'expiresAt': 1793385840},
                {'id': 'c', 'status': 'available', 'expiresAt': None}
            ]}}
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
        let board = NSImage(size: NSSize(width: 600, height: 590), flipped: true) { rect in
            drawingAppearance.performAsCurrentDrawingAppearance {
                NSColor.windowBackgroundColor.setFill(); rect.fill()
                let heading: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16, weight: .semibold), .foregroundColor: NSColor.labelColor]
                ("圆环绘制验证 · 测试输入" as NSString).draw(at: NSPoint(x: 24, y: 20), withAttributes: heading)
                for (index, variant) in variants.enumerated() {
                    let y = CGFloat(65 + index * 56)
                    let label: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor]
                    (variant.0 as NSString).draw(at: NSPoint(x: 24, y: y + 6), withAttributes: label)
                    let actual = RingRenderer.image(variant.1)
                    actual.draw(in: NSRect(x: 306, y: y + 3, width: actual.size.width, height: 18), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                    let enlarged = RingRenderer.image(variant.1, diameter: 36)
                    enlarged.draw(in: NSRect(x: 422, y: y - 6, width: enlarged.size.width, height: 36), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                }
            }
            return true
        }
        try save(board, to: directory.appendingPathComponent("rings-\(name).png"))
        let comparison = NSImage(size: NSSize(width: 520, height: 230), flipped: true) { rect in
            drawingAppearance.performAsCurrentDrawingAppearance {
                NSColor.windowBackgroundColor.setFill(); rect.fill()
                let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor]
                ("满额排版对比 · 左为 18pt，右为 4 倍放大 · 测试输入" as NSString).draw(at: NSPoint(x: 20, y: 16), withAttributes: attributes)
                for (row, nested) in [false, true].enumerated() {
                    let rings = AccountUsage(limits: RateSnapshot(primary: window(0, 10080), secondary: nested ? window(0, 300) : nil), bankedResetCount: 0).rings
                    for (column, text) in ["100", "Full"].enumerated() {
                        let x = CGFloat(20 + column * 260)
                        let y = CGFloat(56 + row * 90)
                        ("\(nested ? "双环" : "单环") · \(text)" as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
                        for (offset, diameter) in [(CGFloat(95), CGFloat(18)), (CGFloat(130), CGFloat(72))] {
                            let image = RingRenderer.render(rings, stale: false, diameter: diameter, includesResets: false, label: text)
                            image.draw(in: NSRect(x: x + offset, y: y - diameter / 2 + 12, width: diameter, height: diameter), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                        }
                    }
                }
            }
            return true
        }
        try save(comparison, to: directory.appendingPathComponent("full-comparison-\(name).png"))
        store.managing = false
        try savePanel(store, height: 403, appearance: appearance, to: directory.appendingPathComponent("overview-\(name).png"))
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

@Test @MainActor func resetMarkersGrowToTwoColumnsAndRenderThreeOverflowDots() throws {
    _ = NSApplication.shared
    for appearanceName in [NSAppearance.Name.aqua, .darkAqua] {
        let appearance = try #require(NSAppearance(named: appearanceName))
        for nested in [false, true] {
            let outer = UsageWindow(usedPercent: 50, windowDurationMins: 10080, resetsAt: nil)
            let inner = UsageWindow(usedPercent: 75, windowDurationMins: 300, resetsAt: nil)
            var previousWidth: CGFloat = 0
            for count in [0, 1, 2, 3, Int.max] {
                let rings = RingPresentation(outer: outer, inner: nested ? inner : nil, bankedResetCount: count)
                let small = RingRenderer.image(rings)
                #expect(small.size.width <= 25.5)
                if count <= 2 { #expect(small.size.width > previousWidth) }
                else { #expect(small.size.width == previousWidth) }
                previousWidth = small.size.width
                #expect(RingRenderer.image(rings, includesResets: false).size.width == 18)
                guard count > 0 else { continue }
                let layout = RingRenderer.resetLayout(rings, diameter: 180)
                let rendered = RingRenderer.image(rings, diameter: 180)
                var tiff: Data?
                appearance.performAsCurrentDrawingAppearance { tiff = rendered.tiffRepresentation }
                let data = try #require(tiff)
                let bitmap = try #require(NSBitmapImageRep(data: data))
                let factor = CGFloat(bitmap.pixelsWide) / rendered.size.width
                for column in 0..<min(2, count) {
                    let x = Int(((layout.firstX + CGFloat(column) * layout.pitch) * factor).rounded())
                    var runs = 0
                    var wasGreen = false
                    for y in 0..<bitmap.pixelsHigh {
                        let pixel = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                        let green = pixel.alphaComponent > 0.5 && pixel.greenComponent > pixel.redComponent * 1.4
                        if green && !wasGreen { runs += 1 }
                        wasGreen = green
                    }
                    #expect(runs == (count >= 3 && column == 1 ? 3 : 1))
                }
            }
        }
    }
    #expect(RingRenderer.image(RingPresentation()).size.width == 18)
}
