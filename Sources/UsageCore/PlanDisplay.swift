import Foundation

public enum PlanDisplay {
    public static func name(_ code: String?) -> String? {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else { return nil }
        switch code.lowercased() {
        // This account's pro tier was explicitly confirmed as Pro 200 by the user.
        // Distinct protocol tiers are not inferred to have the same price.
        case "pro": return "Pro 200"
        case "prolite": return "Pro Lite"
        case "promax": return "Pro Max"
        case "edu": return "Edu"
        case "unknown": return "套餐未知"
        default: return code.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
