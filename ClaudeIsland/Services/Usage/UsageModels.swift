import Foundation

struct UsageWindow: Equatable {
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

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct UsageSummary: Equatable {
    let fiveHour: UsageWindow
    let weekly: UsageWindow
    let lastUpdated: Date
}

enum UsagePlan: String, CaseIterable, Sendable {
    case pro = "Pro"
    case max5x = "Max 5x"
    case max20x = "Max 20x"
    case custom = "Custom"

    var fiveHourLimit: Int {
        switch self {
        case .pro: return 450_000
        case .max5x: return 2_250_000
        case .max20x: return 9_000_000
        case .custom: return AppSettings.customFiveHourLimit
        }
    }

    var weeklyLimit: Int {
        switch self {
        case .pro: return 9_000_000
        case .max5x: return 45_000_000
        case .max20x: return 180_000_000
        case .custom: return AppSettings.customWeeklyLimit
        }
    }
}
