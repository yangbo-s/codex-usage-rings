import AppKit
import UsageCore

enum UsagePalette {
    static let green = adaptive(light: (0.06, 0.58, 0.29), dark: (0.16, 0.81, 0.43))
    private static let blue = adaptive(light: (0.05, 0.42, 0.88), dark: (0.28, 0.65, 1))
    private static let yellow = adaptive(light: (0.68, 0.48, 0.02), dark: (1, 0.80, 0.20))
    private static let red = adaptive(light: (0.85, 0.16, 0.19), dark: (1, 0.36, 0.38))

    static func color(remaining: Double?, stale: Bool = false) -> NSColor {
        guard !stale else { return .secondaryLabelColor }
        switch UsageBand(remaining: remaining) {
        case .high: return green
        case .medium: return blue
        case .low: return yellow
        case .critical: return red
        case .unknown: return .secondaryLabelColor
        }
    }

    private static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> NSColor {
        NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
    }
}
