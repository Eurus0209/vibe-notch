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
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
    }

    func refresh() async {
        let newSummary = await UsageAggregator.shared.computeSummary()
        summary = newSummary
    }
}
