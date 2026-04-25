//
//  UsageModels.swift
//  ClaudeIsland
//
//  Copyright 2026 Hudie LIU.
//  Licensed under the Apache License, Version 2.0 — see LICENSE.md.
//

import Foundation

struct UsageWindow: Equatable, Sendable {
    /// 0.0–1.0, authoritative percentage from Claude's OAuth usage endpoint.
    let percentage: Double
    let resetsAt: Date

    func timeProgress(windowSeconds: TimeInterval) -> Double {
        let remaining = resetsAt.timeIntervalSince(Date())
        guard remaining > 0 else { return 1.0 }
        let elapsed = windowSeconds - remaining
        return min(max(elapsed / windowSeconds, 0), 1.0)
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
    /// Opus-specific weekly window (nil if the account has no Opus limit yet).
    let weeklyOpus: UsageWindow?
    /// Sonnet-specific weekly window (nil if absent).
    let weeklySonnet: UsageWindow?
    let lastUpdated: Date
}
