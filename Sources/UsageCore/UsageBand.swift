import Foundation

/// Match the rounded number the user sees, including at band boundaries.
public enum UsageBand: Equatable {
    case high, medium, low, critical, unknown

    public init(remaining: Double?) {
        guard let remaining, remaining.isFinite else { self = .unknown; return }
        switch min(100, max(0, remaining)).rounded() {
        case 75...: self = .high
        case 50..<75: self = .medium
        case 25..<50: self = .low
        default: self = .critical
        }
    }
}
