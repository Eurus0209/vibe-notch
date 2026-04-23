import Foundation
import os.log

actor UsageAggregator {
    static let shared = UsageAggregator()

    private static let logger = Logger(subsystem: "com.claudeisland", category: "UsageAggregator")

    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private var fileCache: [String: FileCacheEntry] = [:]

    private struct FileCacheEntry {
        let modificationDate: Date
        let entries: [TokenEntry]
    }

    private struct TokenEntry {
        let timestamp: Date
        let outputTokens: Int
    }

    func computeSummary(limits: UsagePlanLimits) -> UsageSummary {
        let now = Date()

        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let weekStart = Self.currentWeekStart(from: now)

        let allEntries = scanAndParseAllJSONL()

        var fiveHourTokens = 0
        var weeklyTokens = 0

        for entry in allEntries {
            if entry.timestamp >= fiveHoursAgo {
                fiveHourTokens += entry.outputTokens
            }
            if entry.timestamp >= weekStart {
                weeklyTokens += entry.outputTokens
            }
        }

        let fiveHourResetAt = now.addingTimeInterval(5 * 3600)
        let nextWeekStart = weekStart.addingTimeInterval(7 * 24 * 3600)

        let summary = UsageSummary(
            fiveHour: UsageWindow(
                used: fiveHourTokens,
                limit: limits.fiveHourLimit,
                resetsAt: fiveHourResetAt
            ),
            weekly: UsageWindow(
                used: weeklyTokens,
                limit: limits.weeklyLimit,
                resetsAt: nextWeekStart
            ),
            lastUpdated: now
        )
        Self.logger.info("Usage: 5h=\(fiveHourTokens)/\(limits.fiveHourLimit) week=\(weeklyTokens)/\(limits.weeklyLimit) entries=\(allEntries.count)")
        return summary
    }

    private func scanAndParseAllJSONL() -> [TokenEntry] {
        let projectsDir = ClaudePaths.projectsDir.path
        let fm = FileManager.default

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: projectsDir) else {
            return []
        }

        var allEntries: [TokenEntry] = []

        for projectDir in projectDirs {
            let projectPath = projectsDir + "/" + projectDir
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectPath, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            guard let files = try? fm.contentsOfDirectory(atPath: projectPath) else {
                continue
            }

            for file in files {
                guard file.hasSuffix(".jsonl") else { continue }
                let filePath = projectPath + "/" + file
                let entries = parseJSONLFile(filePath)
                allEntries.append(contentsOf: entries)
            }
        }

        return allEntries
    }

    private func parseJSONLFile(_ path: String) -> [TokenEntry] {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: path),
              let modDate = attrs[.modificationDate] as? Date else {
            return []
        }

        if let cached = fileCache[path], cached.modificationDate == modDate {
            return cached.entries
        }

        guard let data = fm.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        var entries: [TokenEntry] = []

        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard line.contains("\"assistant\""),
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  json["type"] as? String == "assistant",
                  let message = json["message"] as? [String: Any],
                  let usageDict = message["usage"] as? [String: Any] else {
                continue
            }

            let outputTokens = usageDict["output_tokens"] as? Int ?? 0
            guard outputTokens > 0 else { continue }

            let timestamp: Date
            if let ts = json["timestamp"] as? String, let date = isoFormatter.date(from: ts) {
                timestamp = date
            } else {
                continue
            }

            entries.append(TokenEntry(timestamp: timestamp, outputTokens: outputTokens))
        }

        fileCache[path] = FileCacheEntry(modificationDate: modDate, entries: entries)
        return entries
    }

    static func currentWeekStart(from date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}
