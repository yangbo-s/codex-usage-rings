import AppKit
import CoreText
import UsageCore

/// One geometry is shared by the menu bar, detail view and render tests.
@MainActor
enum RingRenderer {
    nonisolated static let menuDiameter: CGFloat = 18

    static func outerStrokeWidth(nested: Bool, diameter: CGFloat = menuDiameter) -> CGFloat {
        (nested ? 1.15 : 2) * diameter / menuDiameter
    }

    static func image(_ rings: RingPresentation, stale: Bool = false,
                      diameter: CGFloat = menuDiameter, includesResets: Bool = true) -> NSImage {
        render(rings, stale: stale, diameter: diameter, includesResets: includesResets, label: rings.number)
    }

    // The text parameter lets render tests compare labels without adding an application mode.
    static func render(_ rings: RingPresentation, stale: Bool, diameter: CGFloat,
                       includesResets: Bool, label text: String) -> NSImage {
        let count = includesResets ? max(0, rings.bankedResetCount ?? 0) : 0
        let scale = diameter / menuDiameter
        let extra = count > 0 ? 3 + CGFloat(count) * 3 : 0
        let size = NSSize(width: diameter + extra * scale, height: diameter)
        let image = NSImage(size: size, flipped: false) { _ in
            let center = NSPoint(x: diameter / 2, y: diameter / 2)
            let outerWidth = outerStrokeWidth(nested: rings.isNested, diameter: diameter)
            let outerRadius = diameter / 2 - outerWidth / 2 - 0.6 * scale
            let track = NSColor.labelColor.withAlphaComponent(0.18)
            let color = UsagePalette.color(remaining: rings.outer?.remaining, stale: stale)
            stroke(center: center, radius: outerRadius, width: outerWidth,
                   remaining: rings.outer?.remaining, color: color, track: track)
            let innerRadius = 6.2 * scale
            if let inner = rings.inner {
                stroke(center: center, radius: innerRadius, width: 1.05 * scale,
                       remaining: inner.remaining, color: UsagePalette.color(remaining: inner.remaining, stale: stale), track: track)
            }

            let holeRadius = rings.isNested ? innerRadius - 0.525 * scale : outerRadius - outerWidth / 2
            let label = labelLayout(text, holeRadius: holeRadius, scale: scale)
            if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.textMatrix = .identity
                context.textPosition = CGPoint(x: center.x - label.bounds.midX, y: center.y - label.bounds.midY)
                CTLineDraw(label.line, context)
                context.restoreGState()
            }

            // Each available reset is one line; do not infer count from the detail rows.
            for index in 0..<count {
                let x = diameter + (3.5 + CGFloat(index) * 3) * scale
                let line = NSBezierPath()
                line.move(to: NSPoint(x: x, y: 4 * scale))
                line.line(to: NSPoint(x: x, y: diameter - 4 * scale))
                line.lineWidth = outerWidth
                line.lineCapStyle = .round
                (stale ? NSColor.secondaryLabelColor : UsagePalette.green).setStroke()
                line.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    struct LabelLayout {
        let line: CTLine
        let bounds: CGRect
        let fontSize: CGFloat
    }

    static func labelLayout(_ text: String, holeRadius: CGFloat, scale: CGFloat) -> LabelLayout {
        var fontSize = 8 * scale
        while true {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): NSColor.labelColor.cgColor
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
            // Glyph outlines exclude invisible line spacing, so 100 can grow without touching the ring.
            let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            if hypot(bounds.width, bounds.height) <= holeRadius * 2 - 0.6 * scale || fontSize <= 4 * scale {
                return LabelLayout(line: line, bounds: bounds, fontSize: fontSize)
            }
            fontSize -= 0.05 * scale
        }
    }

    private static func stroke(center: NSPoint, radius: CGFloat, width: CGFloat, remaining: Double?,
                               color: NSColor, track: NSColor) {
        let outline = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                                width: radius * 2, height: radius * 2))
        outline.lineWidth = width
        // At zero there is no progress arc; keep a tinted empty track so red is still visible.
        (remaining == 0 ? color.withAlphaComponent(0.55) : track).setStroke()
        outline.stroke()
        guard let remaining, remaining > 0 else { return }
        color.setStroke()
        if remaining >= 100 {
            outline.stroke()
        } else {
            let arc = NSBezierPath()
            arc.lineWidth = width
            arc.lineCapStyle = .round
            arc.appendArc(withCenter: center, radius: radius, startAngle: 90,
                          endAngle: 90 - CGFloat(remaining) * 3.6, clockwise: true)
            arc.stroke()
        }
    }
}
