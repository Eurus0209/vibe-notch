//
//  UsageMonitor.swift
//  ClaudeIsland
//
//  Copyright 2026 Hudie LIU.
//  Licensed under the Apache License, Version 2.0 — see LICENSE.md.
//

import Foundation
import Combine

@MainActor
class UsageMonitor: ObservableObject {
    static let shared = UsageMonitor()

    @Published var summary: UsageSummary?

    private var refreshTask: Task<Void, Never>?

    /// 2 minutes between refreshes (the OAuth usage endpoint is lightweight but we don't need real-time).
    private static let refreshInterval: UInt64 = 120_000_000_000

    func startMonitoring() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: Self.refreshInterval)
            }
        }
    }

    func refresh() async {
        summary = await UsageAggregator.shared.computeSummary()
    }
}
