//
//  UsageAggregator.swift
//  ClaudeIsland
//
//  Copyright 2026 Hudie LIU.
//  Licensed under the Apache License, Version 2.0 — see LICENSE.md.
//

import Foundation
import os.log

actor UsageAggregator {
    static let shared = UsageAggregator()

    private static let logger = Logger(subsystem: "com.claudeisland", category: "UsageAggregator")

    func computeSummary() async -> UsageSummary? {
        do {
            let payload = try await ClaudeOAuthUsageService.shared.fetchUsage()
            guard let fiveHour = payload.fiveHour, let sevenDay = payload.sevenDay else {
                Self.logger.warning("OAuth usage returned no 5h / 7d windows")
                return nil
            }
            return UsageSummary(
                fiveHour: UsageWindow(percentage: fiveHour.utilization, resetsAt: fiveHour.resetsAt),
                weekly: UsageWindow(percentage: sevenDay.utilization, resetsAt: sevenDay.resetsAt),
                weeklyOpus: payload.sevenDayOpus.map {
                    UsageWindow(percentage: $0.utilization, resetsAt: $0.resetsAt)
                },
                weeklySonnet: payload.sevenDaySonnet.map {
                    UsageWindow(percentage: $0.utilization, resetsAt: $0.resetsAt)
                },
                lastUpdated: Date()
            )
        } catch {
            Self.logger.error("computeSummary failed: \(String(describing: error))")
            return nil
        }
    }
}
