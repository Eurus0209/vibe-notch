import Foundation
import Combine

@MainActor
class UsageMonitor: ObservableObject {
    static let shared = UsageMonitor()

    @Published var summary: UsageSummary?

    private var refreshTask: Task<Void, Never>?

    func startMonitoring() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    func refresh() async {
        let plan = AppSettings.usagePlan
        let limits = plan.limits(
            customFiveHour: AppSettings.customFiveHourLimit,
            customWeekly: AppSettings.customWeeklyLimit
        )
        let newSummary = await UsageAggregator.shared.computeSummary(limits: limits)
        summary = newSummary
    }
}
