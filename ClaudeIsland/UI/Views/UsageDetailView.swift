import SwiftUI

struct UsageDetailView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var usageMonitor: UsageMonitor
    @State private var selectedPlan: UsagePlan = AppSettings.usagePlan
    @State private var customFiveHour: String = ""
    @State private var customWeekly: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.1))
            ScrollView {
                VStack(spacing: 20) {
                    ringSection
                    statsSection
                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                    planSection
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Ring

    @ViewBuilder
    private var ringSection: some View {
        let summary = usageMonitor.summary
        let fiveHour = summary?.fiveHour.percentage ?? 0
        let weekly = summary?.weekly.percentage ?? 0

        ZStack {
            UsageRingView(
                fiveHourPercentage: fiveHour,
                weeklyPercentage: weekly,
                size: 120
            )

            VStack(spacing: 2) {
                Text("\(Int(fiveHour * 100))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("5h")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(height: 140)
    }

    // MARK: - Stats

    @ViewBuilder
    private var statsSection: some View {
        if let summary = usageMonitor.summary {
            VStack(spacing: 12) {
                statRow(
                    label: "5h window",
                    used: summary.fiveHour.used,
                    limit: summary.fiveHour.limit,
                    reset: "Rolling window",
                    color: ringColor(for: summary.fiveHour.percentage)
                )
                statRow(
                    label: "This week",
                    used: summary.weekly.used,
                    limit: summary.weekly.limit,
                    reset: "Resets \(summary.weekly.resetDescription)",
                    color: ringColor(for: summary.weekly.percentage)
                )
            }
            .padding(.horizontal, 16)
        } else {
            Text("Scanning...")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    @ViewBuilder
    private func statRow(label: String, used: Int, limit: Int, reset: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(formatTokens(used)) / \(formatTokens(limit))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            HStack {
                Spacer()
                Text(reset)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Plan

    @ViewBuilder
    private var planSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 16)

            HStack(spacing: 6) {
                ForEach(UsagePlan.allCases, id: \.self) { plan in
                    Button {
                        selectedPlan = plan
                        AppSettings.usagePlan = plan
                        Task { await usageMonitor.refresh() }
                    } label: {
                        Text(plan.rawValue)
                            .font(.system(size: 11, weight: selectedPlan == plan ? .semibold : .regular))
                            .foregroundColor(selectedPlan == plan ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedPlan == plan ? Color.white.opacity(0.15) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            if selectedPlan == .custom {
                customLimitsSection
            }
        }
    }

    @ViewBuilder
    private var customLimitsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("5h limit")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 60, alignment: .leading)
                TextField("450000", text: $customFiveHour)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(4)
                    .onSubmit { saveCustomLimits() }
            }
            HStack {
                Text("Weekly")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 60, alignment: .leading)
                TextField("9000000", text: $customWeekly)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(4)
                    .onSubmit { saveCustomLimits() }
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            customFiveHour = String(AppSettings.customFiveHourLimit)
            customWeekly = String(AppSettings.customWeeklyLimit)
        }
    }

    // MARK: - Helpers

    private func saveCustomLimits() {
        if let value = Int(customFiveHour), value > 0 {
            AppSettings.customFiveHourLimit = value
        }
        if let value = Int(customWeekly), value > 0 {
            AppSettings.customWeeklyLimit = value
        }
        Task { await usageMonitor.refresh() }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func ringColor(for percentage: Double) -> Color {
        if percentage > 0.9 {
            return Color(red: 0.95, green: 0.3, blue: 0.3)
        } else if percentage > 0.7 {
            return Color(red: 0.95, green: 0.75, blue: 0.3)
        }
        return Color(red: 0.35, green: 0.65, blue: 1.0)
    }
}
