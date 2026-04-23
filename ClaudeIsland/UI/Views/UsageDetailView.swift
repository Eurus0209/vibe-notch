//
//  UsageDetailView.swift
//  ClaudeIsland
//
//  Copyright 2026 Hudie LIU.
//  Licensed under the Apache License, Version 2.0 — see LICENSE.md.
//

import SwiftUI

struct UsageDetailView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var usageMonitor: UsageMonitor

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.1))
            ScrollView {
                VStack(spacing: 12) {
                    statsSection
                }
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.contentType = .instances
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Usage")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                Task { await usageMonitor.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Stats

    @ViewBuilder
    private var statsSection: some View {
        if let summary = usageMonitor.summary {
            VStack(spacing: 10) {
                statRow(label: "5h", window: summary.fiveHour, windowSeconds: 5 * 3600)
                statRow(label: "Week", window: summary.weekly, windowSeconds: 7 * 24 * 3600)
                if let sonnet = summary.weeklySonnet {
                    statRow(label: "Sonnet", window: sonnet, windowSeconds: 7 * 24 * 3600)
                }
                if let opus = summary.weeklyOpus {
                    statRow(label: "Opus", window: opus, windowSeconds: 7 * 24 * 3600)
                }
            }
            .padding(.horizontal, 16)
        } else {
            VStack(spacing: 6) {
                Text("No usage data")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text("Make sure Claude Code is logged in (token in Keychain).")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func statRow(label: String, window: UsageWindow, windowSeconds: TimeInterval) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 44, alignment: .leading)
            UsageBarView(
                percentage: window.percentage,
                timeProgress: window.timeProgress(windowSeconds: windowSeconds),
                height: 8,
                showTimeMarker: true
            )
            Text("\(Int(window.percentage * 100))%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 40, alignment: .trailing)
            Text("↻ \(window.resetDescription)")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}
