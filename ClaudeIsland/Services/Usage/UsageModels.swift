import Foundation

struct UsageWindow: Equatable, Sendable {
    let used: Int
    let limit: Int
    let resetsAt: Date

    var percentage: Double {
        limit > 0 ? min(Double(used) / Double(limit), 1.0) : 0
    }

    var resetDescription: String {
        let now = Date()
        let remaining = resetsAt.timeIntervalSince(now)
        guard remaining > 0 else { return "now" }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: resetsAt)

        if hours >= 24 {
            let days = hours / 24
            return "\(days)d · \(timeStr)"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m · \(timeStr)"
        }
        return "\(minutes)m · \(timeStr)"
    }
}

struct UsageSummary: Equatable, Sendable {
    let fiveHour: UsageWindow
    let weekly: UsageWindow
    let lastUpdated: Date
}

struct UsagePlanLimits: Sendable {
    let fiveHourLimit: Int
    let weeklyLimit: Int
}

enum UsagePlan: String, CaseIterable, Sendable {
    case pro = "Pro"
    case max5x = "Max 5x"
    case max20x = "Max 20x"
    case custom = "Custom"

    func limits(customFiveHour: Int = 45_000_000, customWeekly: Int = 900_000_000) -> UsagePlanLimits {
        switch self {
        case .pro: return UsagePlanLimits(fiveHourLimit: 45_000_000, weeklyLimit: 900_000_000)
        case .max5x: return UsagePlanLimits(fiveHourLimit: 225_000_000, weeklyLimit: 4_500_000_000)
        case .max20x: return UsagePlanLimits(fiveHourLimit: 900_000_000, weeklyLimit: 18_000_000_000)
        case .custom: return UsagePlanLimits(fiveHourLimit: customFiveHour, weeklyLimit: customWeekly)
        }
    }
}
