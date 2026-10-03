import Foundation

public enum RefreshPolicy {
    public static func interval(lowPower: Bool) -> TimeInterval { lowPower ? 900 : 300 }
    public static func tolerance(lowPower: Bool) -> TimeInterval { interval(lowPower: lowPower) * 0.2 }
    public static func failureDelay(attempt: Int) -> TimeInterval {
        min(3_600, 300 * pow(2, Double(min(5, max(0, attempt - 1)))))
    }
    public static func shouldRefresh(lastUpdate: Date?, nextRetry: Date?, now: Date,
                                     minimumAge: TimeInterval, force: Bool) -> Bool {
        if force { return true }
        if let nextRetry, now < nextRetry { return false }
        return lastUpdate.map { now.timeIntervalSince($0) >= minimumAge } ?? true
    }
}
