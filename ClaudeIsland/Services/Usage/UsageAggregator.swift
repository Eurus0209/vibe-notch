import Foundation
import os.log

actor UsageAggregator {
    static let shared = UsageAggregator()

    private static let logger = Logger(subsystem: "com.claudeisland", category: "UsageAggregator")

    func computeSummary(limits: UsagePlanLimits) -> UsageSummary {
        let now = Date()

        let block = fetchActiveBlock()

        let fiveHourUsed = block?.totalTokens ?? 0
        let fiveHourResetAt: Date
        if let endTime = block?.endTime {
            fiveHourResetAt = endTime
        } else {
            fiveHourResetAt = now.addingTimeInterval(5 * 3600)
        }

        let weeklyUsed = fetchWeeklyTokens()
        let weekStart = Self.currentWeekStart(from: now)
        let nextWeekStart = weekStart.addingTimeInterval(7 * 24 * 3600)

        let summary = UsageSummary(
            fiveHour: UsageWindow(
                used: fiveHourUsed,
                limit: limits.fiveHourLimit,
                resetsAt: fiveHourResetAt
            ),
            weekly: UsageWindow(
                used: weeklyUsed,
                limit: limits.weeklyLimit,
                resetsAt: nextWeekStart
            ),
            lastUpdated: now
        )
        Self.logger.info("Usage: 5h=\(fiveHourUsed)/\(limits.fiveHourLimit) week=\(weeklyUsed)/\(limits.weeklyLimit)")
        return summary
    }

    private struct BlockData {
        let totalTokens: Int
        let endTime: Date?
    }

    private func fetchActiveBlock() -> BlockData? {
        guard let ccusagePath = findCcusage() else {
            Self.logger.warning("ccusage not found, falling back to JSONL scan")
            return fallbackFiveHour()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ccusagePath)
        process.arguments = ["blocks", "--active", "--json", "--offline"]
        process.environment = ProcessInfo.processInfo.environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            Self.logger.error("Failed to run ccusage: \(error.localizedDescription)")
            return fallbackFiveHour()
        }

        guard process.terminationStatus == 0 else {
            return fallbackFiveHour()
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = json["blocks"] as? [[String: Any]],
              let block = blocks.first else {
            return fallbackFiveHour()
        }

        let totalTokens = block["totalTokens"] as? Int ?? 0

        var endTime: Date?
        if let endStr = block["endTime"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            endTime = formatter.date(from: endStr)
        }

        return BlockData(totalTokens: totalTokens, endTime: endTime)
    }

    private func fetchWeeklyTokens() -> Int {
        guard let ccusagePath = findCcusage() else {
            return fallbackWeekly()
        }

        let weekStart = Self.currentWeekStart(from: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let sinceStr = formatter.string(from: weekStart)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ccusagePath)
        process.arguments = ["blocks", "--since", sinceStr, "--json", "--offline"]
        process.environment = ProcessInfo.processInfo.environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return fallbackWeekly()
        }

        guard process.terminationStatus == 0 else {
            return fallbackWeekly()
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = json["blocks"] as? [[String: Any]] else {
            return fallbackWeekly()
        }

        var total = 0
        for block in blocks {
            total += block["totalTokens"] as? Int ?? 0
        }
        return total
    }

    private func findCcusage() -> String? {
        let candidates = [
            "/usr/local/bin/ccusage",
            "\(NSHomeDirectory())/.nvm/versions/node/v20.19.5/bin/ccusage",
            "/opt/homebrew/bin/ccusage",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Search common nvm paths
        let nvmDir = "\(NSHomeDirectory())/.nvm/versions/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) {
            for version in versions.sorted().reversed() {
                let path = "\(nvmDir)/\(version)/bin/ccusage"
                if FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }

        return nil
    }

    // MARK: - Fallback (scan JSONL directly)

    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func fallbackFiveHour() -> BlockData {
        let tokens = scanTokens(since: Date().addingTimeInterval(-5 * 3600))
        return BlockData(totalTokens: tokens, endTime: nil)
    }

    private func fallbackWeekly() -> Int {
        return scanTokens(since: Self.currentWeekStart(from: Date()))
    }

    private func scanTokens(since: Date) -> Int {
        let projectsDir = ClaudePaths.projectsDir.path
        let fm = FileManager.default

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: projectsDir) else {
            return 0
        }

        var total = 0

        for projectDir in projectDirs {
            let projectPath = projectsDir + "/" + projectDir
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectPath, isDirectory: &isDir), isDir.boolValue else { continue }
            guard let files = try? fm.contentsOfDirectory(atPath: projectPath) else { continue }

            for file in files where file.hasSuffix(".jsonl") {
                let filePath = projectPath + "/" + file
                guard let data = fm.contents(atPath: filePath),
                      let content = String(data: data, encoding: .utf8) else { continue }

                for line in content.components(separatedBy: "\n") where !line.isEmpty {
                    guard line.contains("\"assistant\""),
                          let lineData = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                          json["type"] as? String == "assistant",
                          let ts = json["timestamp"] as? String,
                          let date = isoFormatter.date(from: ts),
                          date >= since,
                          let message = json["message"] as? [String: Any],
                          let usage = message["usage"] as? [String: Any] else { continue }

                    total += usage["input_tokens"] as? Int ?? 0
                    total += usage["output_tokens"] as? Int ?? 0
                    total += usage["cache_read_input_tokens"] as? Int ?? 0
                    total += usage["cache_creation_input_tokens"] as? Int ?? 0
                }
            }
        }

        return total
    }

    static func currentWeekStart(from date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}
