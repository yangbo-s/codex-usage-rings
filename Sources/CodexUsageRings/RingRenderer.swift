import AppKit
import UsageCore

/// One geometry is shared by the menu bar, detail view and render tests.
@MainActor
enum RingRenderer {
    nonisolated static let menuDiameter: CGFloat = 20

    static func image(_ rings: RingPresentation, stale: Bool = false,
                      diameter: CGFloat = menuDiameter, includesResets: Bool = true) -> NSImage {
        let count = includesResets ? max(0, rings.bankedResetCount ?? 0) : 0
        let scale = diameter / menuDiameter
        let extra = count > 0 ? 3 + CGFloat(count) * 3 : 0
        let size = NSSize(width: diameter + extra * scale, height: diameter)
        let image = NSImage(size: size, flipped: false) { _ in
            let center = NSPoint(x: diameter / 2, y: diameter / 2)
            let outerWidth: CGFloat = (rings.isNested ? 1.25 : 2.2) * scale
            let outerRadius = diameter / 2 - outerWidth / 2 - 0.6 * scale
            let green = NSColor(srgbRed: 0.16, green: 0.81, blue: 0.43, alpha: 1)
            let innerGreen = NSColor(srgbRed: 0.40, green: 0.91, blue: 0.61, alpha: 1)
            let track = NSColor.labelColor.withAlphaComponent(0.18)
            let color = stale ? NSColor.secondaryLabelColor : green
            stroke(center: center, radius: outerRadius, width: outerWidth,
                   remaining: rings.outer?.remaining, color: color, track: track)
            let innerRadius = 7 * scale
            if let inner = rings.inner {
                stroke(center: center, radius: innerRadius, width: 1.15 * scale,
                       remaining: inner.remaining, color: stale ? .secondaryLabelColor : innerGreen, track: track)
            }

            let holeRadius = rings.isNested ? innerRadius - 0.575 * scale : outerRadius - outerWidth / 2
            let attributes = textAttributes(for: rings.number, holeRadius: holeRadius, scale: scale)
            let label = NSAttributedString(string: rings.number, attributes: attributes)
            let textSize = label.size()
            label.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2))

            // Each available reset is one line; do not infer count from the detail rows.
            for index in 0..<count {
                let x = diameter + (3.5 + CGFloat(index) * 3) * scale
                let line = NSBezierPath()
                line.move(to: NSPoint(x: x, y: 4.5 * scale))
                line.line(to: NSPoint(x: x, y: diameter - 4.5 * scale))
                line.lineWidth = 1.2 * scale
                line.lineCapStyle = .round
                color.setStroke()
                line.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    static func textAttributes(for text: String, holeRadius: CGFloat, scale: CGFloat) -> [NSAttributedString.Key: Any] {
        var fontSize = 8 * scale
        var attributes: [NSAttributedString.Key: Any] = [:]
        repeat {
            attributes = [.font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
                          .foregroundColor: NSColor.labelColor]
            let size = (text as NSString).size(withAttributes: attributes)
            if hypot(size.width, size.height) <= holeRadius * 2 - 0.5 * scale { break }
            fontSize -= 0.2 * scale
        } while fontSize > 4 * scale
        return attributes
    }

    private static func stroke(center: NSPoint, radius: CGFloat, width: CGFloat, remaining: Double?,
                               color: NSColor, track: NSColor) {
        let outline = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                                width: radius * 2, height: radius * 2))
        outline.lineWidth = width
        track.setStroke()
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
