# Usage Display (Dual Ring) — Design & Implementation Plan

> **For agent:** REQUIRED: Use Section 4 or Section 5 to implement this plan.

**Goal:** Add a persistent dual-ring usage indicator to the notch that shows 5-hour rolling window and weekly token consumption against configurable plan limits.

**Architecture:** A new `UsageAggregator` actor scans all JSONL files under `~/.claude/projects/` to compute time-windowed token totals. A `UsageMonitor` (MainActor) publishes summaries to SwiftUI. The closed notch always shows dual concentric rings; tapping opens a detailed usage view.

**Tech Stack:** Swift Concurrency (Actor), SwiftUI Canvas for ring drawing, UserDefaults for plan config, FileManager for JSONL scanning.

---

## Task 1: Data Model — `UsageSummary` and `UsagePlan`

**Files:** Create `ClaudeIsland/Services/Usage/UsageModels.swift`

**Step 1:** Create the file with these types:

```swift
struct UsageWindow: Equatable {
    let used: Int          // output tokens consumed
    let limit: Int         // plan limit
    let resetsAt: Date     // when this window resets
    
    var percentage: Double { limit > 0 ? min(Double(used) / Double(limit), 1.0) : 0 }
    var resetDescription: String { /* e.g. "2h 13m" or "Mon 00:00" */ }
}

struct UsageSummary: Equatable {
    let fiveHour: UsageWindow
    let weekly: UsageWindow
    let lastUpdated: Date
}

enum UsagePlan: String, CaseIterable {
    case pro = "Pro"
    case max5x = "Max 5x"
    case max20x = "Max 20x"
    case custom = "Custom"
    
    var fiveHourLimit: Int { /* default output token limits */ }
    var weeklyLimit: Int { /* 5h limit * ~33.6 windows/week, capped */ }
}
```

**Step 2:** Commit.

---

## Task 2: Settings — Add plan configuration to `AppSettings`

**Files:** Modify `ClaudeIsland/Core/Settings.swift`

**Step 1:** Add keys and properties:
- `usagePlan: UsagePlan` (default: `.pro`)
- `customFiveHourLimit: Int` (default: 450_000)
- `customWeeklyLimit: Int` (default: 9_000_000)

**Step 2:** Commit.

---

## Task 3: Data Layer — `UsageAggregator` actor

**Files:** Create `ClaudeIsland/Services/Usage/UsageAggregator.swift`

**Step 1:** Implement the actor:
- `scanAllJSONL()` — find all `.jsonl` files in `ClaudePaths.projectsDir`
- `aggregateTokens(since:)` — parse each file, extract `output_tokens` from assistant messages whose `timestamp` falls within the window
- `computeSummary() -> UsageSummary` — call aggregate for 5h and weekly windows
- Incremental: cache file offsets and partial sums; only re-parse new data
- Timer-based refresh: 60s idle, 10s when sessions active

**Step 2:** Commit.

---

## Task 4: Monitor — `UsageMonitor` (@MainActor)

**Files:** Create `ClaudeIsland/Services/Usage/UsageMonitor.swift`

**Step 1:** Implement:
- `@Published var summary: UsageSummary?`
- Singleton, starts a Task that calls `UsageAggregator.shared.computeSummary()` on interval
- Publishes updates on MainActor for SwiftUI consumption

**Step 2:** Commit.

---

## Task 5: UI Component — `UsageRingView`

**Files:** Create `ClaudeIsland/UI/Components/UsageRingView.swift`

**Step 1:** Implement a SwiftUI view using Canvas or Circle+trim:
- Two concentric rings (outer = 5h, inner = weekly)
- Color: blue gradient < 70%, yellow 70-90%, red > 90%
- Compact mode (14px for closed notch) and large mode (120px for usage page)
- Smooth animation on value changes

**Step 2:** Commit.

---

## Task 6: UI — `UsageDetailView` (opened content)

**Files:** Create `ClaudeIsland/UI/Views/UsageDetailView.swift`

**Step 1:** Implement the full usage page:
- Large dual ring centered at top
- Below: text stats for each window (used/limit, reset time)
- Bottom: plan picker (UsagePlan selector)
- Custom limit inputs when plan == .custom

**Step 2:** Add `.usage` case to `NotchContentType` enum in `NotchViewModel.swift`
- Add size calculation in `openedSize` (480w × 420h)

**Step 3:** Wire into `contentView` switch in `NotchView.swift`

**Step 4:** Commit.

---

## Task 7: Integration — Closed notch ring + always-visible

**Files:** Modify `ClaudeIsland/UI/Views/NotchView.swift`, `ClaudeIsland/Core/NotchViewModel.swift`

**Step 1:** Add `@StateObject private var usageMonitor = UsageMonitor.shared` to NotchView

**Step 2:** In `headerRow`, add compact `UsageRingView` after the crab icon (always visible, not conditional on `showClosedActivity`)

**Step 3:** Make notch always visible:
- In `onAppear`: set `isVisible = true` unconditionally
- In `handleProcessingChange`: never set `isVisible = false`
- In `handleStatusChange .closed`: never set `isVisible = false`

**Step 4:** Add tap gesture on ring to open usage view: `viewModel.contentType = .usage`

**Step 5:** Add navigation from instances view header (small ring button) to open usage

**Step 6:** Commit.

---

## Task 8: Xcode Project — Add new files

**Files:** Update the Xcode project file to include new Swift files

**Step 1:** Add all new files to the Xcode project build target.

**Step 2:** Build and verify compilation.

**Step 3:** Commit.
