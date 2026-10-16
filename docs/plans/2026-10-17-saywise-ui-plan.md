# Saywise UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. In this project each task is handed to the Codex CLI (`codex exec`, model `gpt-6.1-sol`), one task per run, and the main session checks the result before the next task.

**Goal:** Give Saywise one premium, native Mac window with a Home dashboard, a sidebar, and one dark glass floating bar, plus a stepped first run.

**Architecture:** `ChirpCore` gets one new pure type, `HistoryStats`, computed from history rows and covered by `swift test`. The app target gets a new shell (`RootView` + `Sidebar` in one `NSWindow`), a `Home` folder for the dashboard, a `Components` folder for shared views, and a `FloatingBar` that replaces both the `Pill` and the `FloatingButton`. `AppController` keeps the dictation logic and only changes how it reports state to the bar and the window.

**Tech Stack:** Swift 6, SwiftUI + AppKit, Swift Charts, macOS 15, GRDB 7, Swift Testing, XcodeGen. No new dependencies.

**Spec:** [docs/specs/2026-10-17-saywise-ui-design.md](../specs/2026-10-17-saywise-ui-design.md)

## Global Constraints

- macOS 15.0 minimum. No third-party library added. Swift Charts is a system framework and is allowed.
- One accent (system accent). Live is system red. Good is system green. Warning is system orange. No other color.
- Copy is short. Status is a dot and one or two words. No sentence the user does not need right now.
- The floating bar is a non-activating `NSPanel` (`[.nonactivatingPanel, .borderless]`, `canBecomeKey` and `canBecomeMain` false). It never takes focus.
- The bar is dark in both light and dark mode. Set `NSAppearance(named: .darkAqua)` on the panel only, never on the app.
- Typing speed for "time saved" is 40 words per minute.
- Words are counted by splitting `finalText` on whitespace and newlines and dropping empty parts.
- Every Swift file the plan creates is listed in a task. XcodeGen picks up new files under `App/` on `xcodegen generate`, so each build step runs it first.
- Follow `~/.claude/CODING_HABITS.md`: no comments that restate code, no changes outside the task, no renames of settings keys (`showFloatingButton` stays as the stored key; only the label changes).

## Commands used in every task

```bash
# BUILD: regenerate the project and build the app
cd /Users/abhishekananad/Documents/Chirp && xcodegen generate && xcodebuild -project Chirp.xcodeproj -scheme Chirp -configuration Debug -derivedDataPath build -skipMacroValidation -skipPackagePluginValidation build 2>&1 | tail -20
```

```bash
# TEST: run the core package tests
cd /Users/abhishekananad/Documents/Chirp/Packages/ChirpCore && swift test 2>&1 | tail -20
```

```bash
# RUN: open the built app
open /Users/abhishekananad/Documents/Chirp/build/Build/Products/Debug/Saywise.app
```

A task is done when BUILD ends with `** BUILD SUCCEEDED **` and shows no warning in a file the task touched, and TEST ends with every test passing.

## Decisions made while planning

| # | Decision | Why |
|---|---|---|
| 1 | The bar panel has a fixed size (340 × 80 pt) and is fully transparent. The capsule, its material, stroke and shadow are drawn by SwiftUI inside it. | The width spring then runs entirely in SwiftUI. The panel never resizes, so nothing can flicker and the center stays fixed by construction. Hit testing is limited to the capsule's current width, which the view reports with `onGeometryChange`. |
| 2 | When "Show floating bar" is off, the bar still appears while a recording runs and for flashes, then goes away when it is resting. | This is what the pill did. Without it a hotkey recording would show nothing at all. |
| 3 | A Home recording uses a `CopyInserter` that copies the text and returns `.copiedNoTextField`. | The spec says Home recordings are saved, shown and copied, never pasted. Reusing the existing outcome keeps `finish` simple and the bar shows "Copied". |
| 4 | The record button on Home shows recording and working for every source, and a click during a hotkey recording stops it. | One state per window, as the spec's state table says. |
| 5 | Model progress is shown as a percent. | The loaders report a 0 to 1 fraction, not bytes. The spec allows a percent when bytes are unknown. |
| 6 | The hands-free lock shows for recordings started from the bar or Home, and for a hotkey recording that is hands-free when it starts. | Those recordings do not stop on key release, which is what the lock means. |
| 7 | The welcome and Fn steps of first run show only once, tracked by a `UserDefaults` flag `onboardingSeen`. The other steps show whenever they are needed. | "Steps already done are skipped" needs a record of having seen the one-time steps. |

## File structure

| Path | Responsibility |
|---|---|
| `Packages/ChirpCore/Sources/ChirpCore/Storage/HistoryStats.swift` | Pure stats from `[HistoryEntry]`. |
| `Packages/ChirpCore/Sources/ChirpCore/Storage/HistoryStore.swift` | Adds `stats(now:calendar:)` that loads the last 60 days and computes. |
| `Packages/ChirpCore/Tests/ChirpCoreTests/HistoryStatsTests.swift` | Stats tests with fixed dates. |
| `App/UI/Components/WaveView.swift` | Bars from levels. Shared by the bar and the Talk card. |
| `App/UI/Components/StatusDot.swift` | 8 pt dot, optional pulse. |
| `App/UI/Components/Card.swift` | The 16 pt rounded card. |
| `App/UI/Components/Banner.swift` | Orange attention banner with one button. |
| `App/UI/Components/RecordButton.swift` | 64 pt record button with the breathing ring. |
| `App/UI/Components/PageColumn.swift` | Centered 760 pt content column with title and help line. |
| `App/UI/Components/VisualEffectView.swift` | `NSVisualEffectView` wrapper. |
| `App/UI/Components/CountUpText.swift` | Animatable number text. |
| `App/UI/Components/AppIcon.swift` | App icon by bundle id, cached. |
| `App/UI/FloatingBar/BarModel.swift` | Phase and levels of the bar. |
| `App/UI/FloatingBar/FloatingBarView.swift` | The capsule and its states. |
| `App/UI/FloatingBar/FloatingBarPanel.swift` | Non-activating panel and the click-vs-drag host view. |
| `App/UI/FloatingBar/FloatingBarController.swift` | Shows phases, flashes, placement, visibility. |
| `App/UI/Shell/Page.swift` | The sidebar pages and the shared `Navigation` state. |
| `App/UI/Shell/RootView.swift` | `NavigationSplitView` with the page switch. |
| `App/UI/Shell/Sidebar.swift` | Sidebar items and the status row. |
| `App/UI/WindowCoordinator.swift` | One main window, the setup window. |
| `App/UI/Home/HomeModel.swift` | Loads stats and recent, greeting. |
| `App/UI/Home/HomeView.swift` | Header, banner slot, Talk card, stats, activity, two half cards. |
| `App/UI/Home/TalkCard.swift`, `StatCard.swift`, `ActivityChart.swift`, `TopAppsCard.swift`, `RecentCard.swift` | One view each. |
| `App/UI/HistoryView.swift` | Grouped list, expand in place, focus from Home. |
| `App/UI/Settings/SettingsView.swift` | One grouped form. |
| `App/UI/Settings/ListPages.swift` | Dictionary, Snippets, App styles pages (renamed from `ListTabs.swift`). |
| `App/UI/OnboardingView.swift` | Stepped first run (replaces `SetupView.swift`). |
| `App/UI/MenuContent.swift` | Menu bar items. |
| `App/AppController.swift` | Bar wiring, short status strings, hints, copy inserter, hotkey restart flag. |
| `App/System/Permissions.swift` | Short reasons, banner text, request-or-open-settings. |
| Deleted | `App/UI/MainView.swift`, `App/UI/Pill.swift`, `App/UI/FloatingButton.swift`, `App/UI/SetupView.swift`, `App/UI/Settings/ListTabs.swift`. |

---

### Task 1: HistoryStats

**Files:**
- Create: `Packages/ChirpCore/Sources/ChirpCore/Storage/HistoryStats.swift`
- Test: `Packages/ChirpCore/Tests/ChirpCoreTests/HistoryStatsTests.swift`

**Interfaces:**
- Consumes: `HistoryEntry` (`createdAt`, `finalText`, `audioSeconds`, `appBundleID`, `appName`).
- Produces: `HistoryStats` with `wordsToday`, `wordsYesterday`, `wordsThisWeek`, `dictationsThisWeek`, `secondsSavedThisWeek`, `streakDays`, `bestStreakDays`, `last14Days: [HistoryStats.Day]`, `topApps: [HistoryStats.AppWords]`, `static func compute(entries:now:calendar:)`, `static func wordCount(_:)`, `static func empty(now:calendar:)`.

- [ ] **Step 1: Write the failing tests**

Create `Packages/ChirpCore/Tests/ChirpCoreTests/HistoryStatsTests.swift`:

```swift
import Foundation
import Testing
@testable import ChirpCore

struct HistoryStatsTests {
    // Thursday 2026-10-15 12:00 UTC. The week (Monday first) starts 2026-10-12.
    let now = Date(timeIntervalSince1970: 1_792_065_600)

    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }

    func entry(_ text: String, daysAgo: Int, hour: Int = 10, app: String? = "Slack",
               bundleID: String? = "com.tinyspeck.slackmacgap", audioSeconds: Double = 5) -> HistoryEntry {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let at = calendar.date(byAdding: .hour, value: hour, to: day)!
        return HistoryEntry(
            createdAt: at, appBundleID: bundleID, appName: app, style: "chat", language: "auto",
            audioSeconds: audioSeconds, rawText: text, finalText: text, cleanup: "used",
            insertOutcome: "pasted", transcribeMs: 1, cleanupMs: 1, insertMs: 1, totalMs: 3, audioFileName: nil)
    }

    func stats(_ entries: [HistoryEntry]) -> HistoryStats {
        HistoryStats.compute(entries: entries, now: now, calendar: calendar)
    }

    @Test func wordCountSplitsOnWhitespaceAndDropsEmptyParts() {
        #expect(HistoryStats.wordCount("kal  meeting hai\n5 baje ") == 5)
        #expect(HistoryStats.wordCount("") == 0)
        #expect(HistoryStats.wordCount("   ") == 0)
    }

    @Test func emptyInputGivesZerosAndFourteenDays() {
        let s = stats([])
        #expect(s.wordsToday == 0)
        #expect(s.wordsThisWeek == 0)
        #expect(s.dictationsThisWeek == 0)
        #expect(s.secondsSavedThisWeek == 0)
        #expect(s.streakDays == 0)
        #expect(s.bestStreakDays == 0)
        #expect(s.last14Days.count == 14)
        #expect(s.last14Days.allSatisfy { $0.words == 0 })
        #expect(s.topApps.isEmpty)
        #expect(s == HistoryStats.empty(now: now, calendar: calendar))
    }

    @Test func todayAndYesterdayAreCountedSeparately() {
        let s = stats([entry("one two three", daysAgo: 0), entry("four five", daysAgo: 0), entry("six", daysAgo: 1)])
        #expect(s.wordsToday == 5)
        #expect(s.wordsYesterday == 1)
        #expect(s.last14Days.last?.words == 5)
        #expect(s.last14Days[12].words == 1)
    }

    @Test func last14DaysIsOldestFirstAndEndsToday() {
        let s = stats([])
        let today = calendar.startOfDay(for: now)
        #expect(s.last14Days.last?.date == today)
        #expect(s.last14Days.first?.date == calendar.date(byAdding: .day, value: -13, to: today))
    }

    @Test func weekStartsOnMondayAndExcludesLastSunday() {
        // Thursday: 3 days ago is Monday (in week), 4 days ago is Sunday (out).
        let s = stats([entry("a b", daysAgo: 3), entry("c d e", daysAgo: 4), entry("f", daysAgo: 0)])
        #expect(s.wordsThisWeek == 3)
        #expect(s.dictationsThisWeek == 2)
    }

    @Test func timeSavedIsTypingTimeMinusSpeakingTimeAndNeverNegative() {
        // 40 words at 40 wpm = 60 s typing, spoken in 20 s -> 40 s saved.
        let forty = Array(repeating: "w", count: 40).joined(separator: " ")
        // 2 words = 3 s typing, spoken in 10 s -> 0, not -7.
        let s = stats([entry(forty, daysAgo: 0, audioSeconds: 20), entry("a b", daysAgo: 1, audioSeconds: 10)])
        #expect(s.secondsSavedThisWeek == 40)
    }

    @Test func streakCountsConsecutiveDaysEndingToday() {
        let s = stats([entry("a", daysAgo: 0), entry("a", daysAgo: 1), entry("a", daysAgo: 2), entry("a", daysAgo: 4)])
        #expect(s.streakDays == 3)
    }

    @Test func streakStillCountsWhenTodayIsEmpty() {
        let s = stats([entry("a", daysAgo: 1), entry("a", daysAgo: 2)])
        #expect(s.streakDays == 2)
    }

    @Test func streakIsZeroWhenYesterdayAndTodayAreEmpty() {
        let s = stats([entry("a", daysAgo: 2), entry("a", daysAgo: 3)])
        #expect(s.streakDays == 0)
        #expect(s.bestStreakDays == 2)
    }

    @Test func bestStreakIsTheLongestRun() {
        let s = stats([
            entry("a", daysAgo: 0),
            entry("a", daysAgo: 10), entry("a", daysAgo: 11), entry("a", daysAgo: 12), entry("a", daysAgo: 13),
        ])
        #expect(s.streakDays == 1)
        #expect(s.bestStreakDays == 4)
    }

    @Test func topAppsAreThisWeekMostWordsFirstMaxFive() {
        var entries: [HistoryEntry] = []
        for (i, name) in ["A", "B", "C", "D", "E", "F"].enumerated() {
            entries.append(entry(Array(repeating: "w", count: i + 1).joined(separator: " "), daysAgo: 0, app: name, bundleID: "app.\(name)"))
        }
        entries.append(entry("x x x x x x x x x x", daysAgo: 5, app: "Old", bundleID: "app.old"))
        let s = stats(entries)
        #expect(s.topApps.count == 5)
        #expect(s.topApps.map(\.name) == ["F", "E", "D", "C", "B"])
        #expect(s.topApps.first?.words == 6)
        #expect(s.topApps.first?.bundleID == "app.F")
    }

    @Test func topAppsFallBackToBundleIDThenUnknown() {
        let s = stats([entry("a", daysAgo: 0, app: nil, bundleID: "com.x"), entry("b", daysAgo: 0, app: nil, bundleID: nil)])
        #expect(Set(s.topApps.map(\.name)) == ["com.x", "Unknown"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /Users/abhishekananad/Documents/Chirp/Packages/ChirpCore && swift test --filter HistoryStatsTests 2>&1 | tail -5`
Expected: compile error, `cannot find 'HistoryStats' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Packages/ChirpCore/Sources/ChirpCore/Storage/HistoryStats.swift`:

```swift
import Foundation

/// Numbers for the Home page, computed from history rows. Pure, so tests pass a fixed `now`.
public struct HistoryStats: Equatable, Sendable {
    public struct Day: Equatable, Sendable {
        public var date: Date
        public var words: Int

        public init(date: Date, words: Int) {
            self.date = date
            self.words = words
        }
    }

    public struct AppWords: Equatable, Sendable {
        public var bundleID: String?
        public var name: String
        public var words: Int

        public init(bundleID: String?, name: String, words: Int) {
            self.bundleID = bundleID
            self.name = name
            self.words = words
        }
    }

    public static let typingWordsPerMinute = 40.0
    public static let dayCount = 14
    public static let topAppLimit = 5

    public var wordsToday: Int
    public var wordsYesterday: Int
    public var wordsThisWeek: Int
    public var dictationsThisWeek: Int
    public var secondsSavedThisWeek: Double
    public var streakDays: Int
    public var bestStreakDays: Int
    /// Oldest first, always `dayCount` items, the last one is today.
    public var last14Days: [Day]
    /// This week, most words first, at most `topAppLimit`.
    public var topApps: [AppWords]

    public static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    public static func empty(now: Date, calendar: Calendar) -> HistoryStats {
        compute(entries: [], now: now, calendar: calendar)
    }

    public static func compute(entries: [HistoryEntry], now: Date, calendar: Calendar) -> HistoryStats {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today

        var wordsByDay: [Date: Int] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            wordsByDay[day, default: 0] += wordCount(entry.finalText)
        }

        let days = (0..<dayCount).reversed().map { offset -> Day in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return Day(date: date, words: wordsByDay[date] ?? 0)
        }

        let week = entries.filter { $0.createdAt >= weekStart }
        let wordsThisWeek = week.reduce(0) { $0 + wordCount($1.finalText) }
        let secondsSaved = week.reduce(0.0) { total, entry in
            let typing = Double(wordCount(entry.finalText)) / typingWordsPerMinute * 60
            return total + max(0, typing - entry.audioSeconds)
        }

        var byApp: [String: AppWords] = [:]
        for entry in week {
            let key = entry.appBundleID ?? entry.appName ?? "Unknown"
            let name = entry.appName ?? entry.appBundleID ?? "Unknown"
            var app = byApp[key] ?? AppWords(bundleID: entry.appBundleID, name: name, words: 0)
            app.words += wordCount(entry.finalText)
            byApp[key] = app
        }
        let topApps = Array(byApp.values.sorted { ($0.words, $1.name) > ($1.words, $0.name) }.prefix(topAppLimit))

        let activeDays = Set(wordsByDay.keys)
        let streakDays = streak(from: activeDays.contains(today) ? today : yesterday, in: activeDays, calendar: calendar)

        return HistoryStats(
            wordsToday: wordsByDay[today] ?? 0,
            wordsYesterday: wordsByDay[yesterday] ?? 0,
            wordsThisWeek: wordsThisWeek,
            dictationsThisWeek: week.count,
            secondsSavedThisWeek: secondsSaved,
            streakDays: streakDays,
            bestStreakDays: bestStreak(in: activeDays, calendar: calendar),
            last14Days: days,
            topApps: topApps)
    }

    private static func streak(from start: Date, in days: Set<Date>, calendar: Calendar) -> Int {
        var count = 0
        var day = start
        while days.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    private static func bestStreak(in days: Set<Date>, calendar: Calendar) -> Int {
        var best = 0
        for day in days {
            let previous = calendar.date(byAdding: .day, value: -1, to: day)!
            guard !days.contains(previous) else { continue }
            best = max(best, streakForward(from: day, in: days, calendar: calendar))
        }
        return best
    }

    private static func streakForward(from start: Date, in days: Set<Date>, calendar: Calendar) -> Int {
        var count = 0
        var day = start
        while days.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return count
    }
}
```

Note on the sort: `($0.words, $1.name) > ($1.words, $0.name)` sorts words descending and, for equal words, names ascending.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /Users/abhishekananad/Documents/Chirp/Packages/ChirpCore && swift test --filter HistoryStatsTests 2>&1 | tail -5`
Expected: `Test run with 12 tests passed`.

- [ ] **Step 5: Commit**

```bash
cd /Users/abhishekananad/Documents/Chirp && git add Packages/ChirpCore/Sources/ChirpCore/Storage/HistoryStats.swift Packages/ChirpCore/Tests/ChirpCoreTests/HistoryStatsTests.swift && git commit -m "Add HistoryStats for the Home page"
```

---

### Task 2: HistoryStore.stats

**Files:**
- Modify: `Packages/ChirpCore/Sources/ChirpCore/Storage/HistoryStore.swift` (add one method after `recent`)
- Test: `Packages/ChirpCore/Tests/ChirpCoreTests/HistoryStatsTests.swift` (add one test)

**Interfaces:**
- Consumes: `HistoryStats.compute(entries:now:calendar:)` from Task 1.
- Produces: `func stats(now: Date = Date(), calendar: Calendar = .current) async throws -> HistoryStats` on `HistoryStore`.

- [ ] **Step 1: Write the failing test**

Add to the end of `HistoryStatsTests` (inside the struct):

```swift
    @Test func storeStatsLoadsOnlyTheLastSixtyDays() async throws {
        let store = try HistoryStore()
        try await store.save(entry("a b c", daysAgo: 0))
        try await store.save(entry("d", daysAgo: 59))
        try await store.save(entry("e f g h", daysAgo: 61))
        let s = try await store.stats(now: now, calendar: calendar)
        #expect(s.wordsToday == 3)
        #expect(s.bestStreakDays == 1)
        #expect(s.last14Days.last?.words == 3)
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/abhishekananad/Documents/Chirp/Packages/ChirpCore && swift test --filter HistoryStatsTests 2>&1 | tail -5`
Expected: compile error, `value of type 'HistoryStore' has no member 'stats'`.

- [ ] **Step 3: Add the method**

In `HistoryStore.swift`, after the `recent(limit:search:)` method, add:

```swift
    /// Home page numbers. Loads 60 days so the streak has room; older rows never matter to the stats.
    public func stats(now: Date = Date(), calendar: Calendar = .current) async throws -> HistoryStats {
        let since = calendar.date(byAdding: .day, value: -60, to: calendar.startOfDay(for: now)) ?? now
        let entries = try await db.read { db in
            try HistoryEntry.filter(Column("createdAt") >= since).fetchAll(db)
        }
        return HistoryStats.compute(entries: entries, now: now, calendar: calendar)
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /Users/abhishekananad/Documents/Chirp/Packages/ChirpCore && swift test 2>&1 | tail -5`
Expected: all tests pass, 13 in `HistoryStatsTests`.

- [ ] **Step 5: Commit**

```bash
cd /Users/abhishekananad/Documents/Chirp && git add Packages/ChirpCore && git commit -m "Add HistoryStore.stats"
```

---

### Task 3: Shared components

**Files:**
- Create: `App/UI/Components/WaveView.swift`, `App/UI/Components/StatusDot.swift`, `App/UI/Components/Card.swift`, `App/UI/Components/Banner.swift`, `App/UI/Components/RecordButton.swift`, `App/UI/Components/PageColumn.swift`, `App/UI/Components/VisualEffectView.swift`, `App/UI/Components/CountUpText.swift`, `App/UI/Components/AppIcon.swift`

**Interfaces:**
- Produces: `WaveView(levels:barWidth:gap:minHeight:maxHeight:)`, `StatusDot(color:pulses:)`, `Card { }`, `Banner(text:button:action:)`, `RecordButton(state:action:)` with `RecordButton.State { idle, recording, working, disabled }`, `PageColumn(title:help:) { }`, `VisualEffectView(material:blending:)`, `CountUpText(value:format:)`, `AppIcon(bundleID:size:)`.

These are views with no logic to unit test. The check is BUILD.

- [ ] **Step 1: Create `App/UI/Components/WaveView.swift`**

```swift
import SwiftUI

/// Bars that rise with the recorder's levels. Color comes from the parent's foreground style.
struct WaveView: View {
    let levels: [Float]
    var barWidth: CGFloat = 3
    var gap: CGFloat = 2
    var minHeight: CGFloat = 4
    var maxHeight: CGFloat = 24

    var body: some View {
        HStack(alignment: .center, spacing: gap) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .frame(width: barWidth, height: minHeight + CGFloat(min(1, level * 12)) * (maxHeight - minHeight))
            }
        }
        .frame(height: maxHeight)
        .animation(.easeOut(duration: 0.08), value: levels)
    }
}
```

- [ ] **Step 2: Create `App/UI/Components/StatusDot.swift`**

```swift
import SwiftUI

struct StatusDot: View {
    let color: Color
    var pulses = false
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(pulses && dim ? 0.4 : 1)
            .animation(pulses ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: dim)
            .onAppear { dim = pulses }
            .onChange(of: pulses) { dim = pulses }
    }
}
```

- [ ] **Step 3: Create `App/UI/Components/Card.swift`**

```swift
import SwiftUI

struct Card<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator, lineWidth: 0.5))
    }
}
```

- [ ] **Step 4: Create `App/UI/Components/Banner.swift`**

```swift
import SwiftUI

struct Banner: View {
    let text: String
    let button: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            Text(text).font(.callout)
            Spacer()
            Button(button, action: action).buttonStyle(.bordered).controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.orange.opacity(0.12)))
    }
}
```

- [ ] **Step 5: Create `App/UI/Components/RecordButton.swift`**

```swift
import SwiftUI

struct RecordButton: View {
    enum State: Equatable { case idle, recording, working, disabled }

    let state: State
    let action: () -> Void
    @SwiftUI.State private var hovering = false
    @SwiftUI.State private var pressed = false
    @SwiftUI.State private var breathing = false

    var body: some View {
        ZStack {
            if state == .recording {
                Circle()
                    .fill(.red.opacity(0.25))
                    .scaleEffect(breathing ? 1.18 : 1)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: breathing)
                    .onAppear { breathing = true }
                    .onDisappear { breathing = false }
            }
            Circle().fill(fill)
            switch state {
            case .working:
                ProgressView().controlSize(.small).tint(.white)
            case .recording:
                Image(systemName: "stop.fill").font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
            case .idle:
                Image(systemName: "mic.fill").font(.system(size: 24, weight: .semibold)).foregroundStyle(Color(nsColor: .windowBackgroundColor))
            case .disabled:
                Image(systemName: "mic.fill").font(.system(size: 24, weight: .semibold)).foregroundStyle(.tertiary)
            }
        }
        .frame(width: 64, height: 64)
        .scaleEffect(pressed ? 0.96 : (hovering && isClickable ? 1.04 : 1))
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.easeOut(duration: 0.08), value: pressed)
        .contentShape(Circle())
        .onHover { hovering = $0 }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if isClickable { pressed = true } }
                .onEnded { _ in
                    pressed = false
                    if isClickable { action() }
                })
        .accessibilityLabel(state == .recording ? "Stop" : "Talk")
    }

    private var isClickable: Bool { state == .idle || state == .recording }

    private var fill: AnyShapeStyle {
        switch state {
        case .idle: AnyShapeStyle(.primary)
        case .recording: AnyShapeStyle(.red)
        case .working: AnyShapeStyle(.primary.opacity(0.6))
        case .disabled: AnyShapeStyle(.quaternary)
        }
    }
}
```

- [ ] **Step 6: Create `App/UI/Components/PageColumn.swift`**

```swift
import SwiftUI

/// The content column every page uses: 760 pt wide, centered, 32 pt padding, room for the hidden title bar.
struct PageColumn<Content: View>: View {
    var title: String?
    var help: String?
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let title {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.largeTitle.bold())
                        if let help {
                            Text(help).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
                content
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 44)
            .padding(.bottom, 32)
        }
    }
}
```

- [ ] **Step 7: Create `App/UI/Components/VisualEffectView.swift`**

```swift
import AppKit
import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}
```

- [ ] **Step 8: Create `App/UI/Components/CountUpText.swift`**

```swift
import SwiftUI

/// Text whose number animates when `value` changes under `withAnimation`.
struct CountUpText: View, Animatable {
    var value: Double
    let format: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(value))
    }
}
```

- [ ] **Step 9: Create `App/UI/Components/AppIcon.swift`**

```swift
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppIcon: View {
    let bundleID: String?
    var size: CGFloat = 20

    var body: some View {
        Image(nsImage: Self.icon(for: bundleID))
            .resizable()
            .frame(width: size, height: size)
    }

    @MainActor private static var cache: [String: NSImage] = [:]

    @MainActor static func icon(for bundleID: String?) -> NSImage {
        guard let bundleID else { return generic }
        if let cached = cache[bundleID] { return cached }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) } ?? generic
        cache[bundleID] = icon
        return icon
    }

    private static var generic: NSImage { NSWorkspace.shared.icon(for: .application) }
}
```

- [ ] **Step 10: Build**

Run BUILD.
Expected: `** BUILD SUCCEEDED **`. The new files compile but nothing uses them yet.

- [ ] **Step 11: Commit**

```bash
cd /Users/abhishekananad/Documents/Chirp && git add App/UI/Components && git commit -m "Add shared UI components"
```

---

### Task 4: Floating bar and controller wiring

**Files:**
- Create: `App/UI/FloatingBar/BarModel.swift`, `App/UI/FloatingBar/FloatingBarView.swift`, `App/UI/FloatingBar/FloatingBarPanel.swift`, `App/UI/FloatingBar/FloatingBarController.swift`
- Delete: `App/UI/Pill.swift`, `App/UI/FloatingButton.swift`
- Modify: `App/AppController.swift`, `App/UI/MainView.swift` (two small edits so it still compiles until Task 5 deletes it)

**Interfaces:**
- Consumes: `WaveView`, `StatusDot`, `VisualEffectView` from Task 3.
- Produces: `BarModel.Phase`, `FloatingBarController` with `model`, `onClick`, `setVisible(_:)`, `setRest(_:)`, `show(_:)`, `flash(_:symbol:warning:seconds:)`, `showPasted()`, `settle()`. On `AppController`: `bar`, `statusText` (short), `statusHint`, `modelProgressText`, `needsAttention`, `hotkeyNeedsRestart`, `startRecording` showing the bar for every source.

- [ ] **Step 1: Create `App/UI/FloatingBar/BarModel.swift`**

```swift
import Observation
import SwiftUI

@MainActor
@Observable
final class BarModel {
    enum Phase: Equatable {
        case idle
        case micOff
        case loading
        case listening(handsFree: Bool)
        case finishing
        case pasted
        case message(String, symbol: String, warning: Bool)

        /// A resting phase is what the bar shows when nothing is happening.
        var isResting: Bool {
            switch self {
            case .idle, .micOff, .loading: true
            default: false
            }
        }
    }

    static let barCount = 20

    var phase: Phase = .idle
    var levels = Array(repeating: Float(0), count: barCount)
    var hovering = false
    var showsEscape = false
    /// The capsule's laid-out width. The transparent panel only reacts to clicks inside it.
    var contentWidth: CGFloat = 52

    func push(_ level: Float) {
        levels.removeFirst()
        levels.append(level)
    }

    func resetLevels() {
        levels = Array(repeating: 0, count: Self.barCount)
    }
}
```

- [ ] **Step 2: Create `App/UI/FloatingBar/FloatingBarView.swift`**

```swift
import SwiftUI

struct FloatingBarView: View {
    let model: BarModel

    var body: some View {
        content
            .font(.system(size: 13, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(height: 34)
            .background(VisualEffectView(material: .hudWindow))
            .background(Color.black.opacity(model.hovering && model.phase == .idle ? 0.42 : 0.3))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(model.hovering && model.phase == .idle ? 0.2 : 0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
            .scaleEffect(model.hovering && model.phase == .idle ? 1.03 : 1)
            .opacity(model.phase == .micOff ? 0.7 : 1)
            .fixedSize()
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.phase)
            .animation(.easeOut(duration: 0.12), value: model.hovering)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { model.contentWidth = $0 }
            .onHover { model.hovering = $0 }
            .help(help)
    }

    @ViewBuilder private var content: some View {
        ZStack {
            switch model.phase {
            case .idle:
                Image(systemName: "mic.fill").font(.system(size: 14)).opacity(0.85).frame(width: 52)
            case .micOff:
                Image(systemName: "mic.slash.fill").font(.system(size: 14)).opacity(0.5).frame(width: 52)
            case .loading:
                ProgressView().controlSize(.small).tint(.white).opacity(0.7).frame(width: 52)
            case let .listening(handsFree):
                HStack(spacing: 0) {
                    if handsFree {
                        Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.red)
                    } else {
                        StatusDot(color: .red, pulses: true)
                    }
                    Spacer()
                    WaveView(levels: model.levels, barWidth: 2.5, maxHeight: 18)
                    Spacer()
                    Text("esc")
                        .font(.system(size: 10))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white, lineWidth: 1))
                        .opacity(model.showsEscape ? 0.5 : 0)
                        .animation(.easeOut(duration: 0.15), value: model.showsEscape)
                }
                .padding(.horizontal, 12)
                .frame(width: 184)
            case .finishing:
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small).tint(.white)
                    Text("Finishing")
                }
                .padding(.horizontal, 14)
            case .pasted:
                Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(.green).frame(width: 52)
            case let .message(text, symbol, warning):
                HStack(spacing: 9) {
                    Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(warning ? .orange : .white).opacity(warning ? 1 : 0.85)
                    Text(text).lineLimit(1)
                }
                .padding(.horizontal, 14)
            }
        }
        .transition(.opacity)
        .id(phaseKey)
        .animation(.easeOut(duration: 0.15), value: phaseKey)
    }

    private var phaseKey: String {
        switch model.phase {
        case .idle: "idle"
        case .micOff: "micOff"
        case .loading: "loading"
        case let .listening(handsFree): "listening-\(handsFree)"
        case .finishing: "finishing"
        case .pasted: "pasted"
        case let .message(text, _, _): "message-\(text)"
        }
    }

    private var help: String {
        switch model.phase {
        case .idle: "Talk · drag to move"
        case .listening: "Click to stop"
        case .micOff: "Mic is off · click to turn on"
        default: ""
        }
    }
}
```

- [ ] **Step 3: Create `App/UI/FloatingBar/FloatingBarPanel.swift`**

```swift
import AppKit
import SwiftUI

/// Click toggles recording, drag moves the panel. AppKit handles the mouse so a drag never counts as a click.
/// Only the capsule reacts; the rest of the fixed-size panel is see-through.
final class FloatingBarHostView: NSView {
    var onClick: () -> Void = {}
    var onMoved: () -> Void = {}
    var capsuleWidth: () -> CGFloat = { 52 }
    private var dragStart: NSPoint?
    private var windowStart: NSPoint?
    private var dragged = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let width = capsuleWidth()
        let capsule = NSRect(x: bounds.midX - width / 2, y: bounds.midY - 17, width: width, height: 34)
        return capsule.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart, let windowStart, let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - dragStart.x
        let dy = now.y - dragStart.y
        if !dragged && hypot(dx, dy) < 4 { return }
        dragged = true
        window.setFrameOrigin(NSPoint(x: windowStart.x + dx, y: windowStart.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if dragged { onMoved() } else { onClick() }
        dragStart = nil
        windowStart = nil
    }
}

/// Never takes focus, so the text still pastes into the app the user was typing in.
final class FloatingBarPanel: NSPanel {
    init(content: NSView) {
        super.init(
            contentRect: NSRect(origin: .zero, size: FloatingBarController.panelSize),
            styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isExcludedFromWindowsMenu = true
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = content
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 4: Create `App/UI/FloatingBar/FloatingBarController.swift`**

```swift
import AppKit
import SwiftUI

@MainActor
final class FloatingBarController {
    static let panelSize = NSSize(width: 340, height: 80)
    private static let centerKey = "floatingBarCenter"
    private static let edgeMargin: CGFloat = 12
    private static let bottomGap: CGFloat = 20

    let model = BarModel()
    var onClick: () -> Void = {}

    private let panel: FloatingBarPanel
    private var wantsVisible = false
    private var restPhase: BarModel.Phase = .idle
    private var revertTask: Task<Void, Never>?
    private var escapeTask: Task<Void, Never>?

    init() {
        let host = FloatingBarHostView(frame: NSRect(origin: .zero, size: Self.panelSize))
        let hosting = NSHostingView(rootView: FloatingBarView(model: model))
        hosting.frame = host.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.layer?.backgroundColor = .clear
        host.addSubview(hosting)
        panel = FloatingBarPanel(content: host)
        host.capsuleWidth = { [model] in model.contentWidth }
        host.onClick = { [weak self] in self?.onClick() }
        host.onMoved = { [weak self] in self?.saveCenter() }
    }

    /// The "Show floating bar" setting. Off still shows the bar while something is happening.
    func setVisible(_ visible: Bool) {
        wantsVisible = visible
        place()
        applyVisibility()
    }

    /// What the bar shows when nothing is happening: idle, mic off or loading.
    func setRest(_ phase: BarModel.Phase) {
        restPhase = phase
        if model.phase.isResting { model.phase = phase }
        applyVisibility()
    }

    func show(_ phase: BarModel.Phase) {
        revertTask?.cancel()
        escapeTask?.cancel()
        model.showsEscape = false
        if case .listening = phase {
            model.resetLevels()
            escapeTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.model.showsEscape = true
            }
        }
        model.phase = phase
        applyVisibility()
    }

    func flash(_ text: String, symbol: String, warning: Bool = false, seconds: Double = 3) {
        show(.message(text, symbol: symbol, warning: warning))
        revert(after: seconds)
    }

    func showPasted() {
        show(.pasted)
        revert(after: 0.4)
    }

    /// Back to the resting phase.
    func settle() {
        show(restPhase)
    }

    private func revert(after seconds: Double) {
        revertTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.settle()
        }
    }

    private func applyVisibility() {
        if wantsVisible || !model.phase.isResting {
            if !panel.isVisible { place() }
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    // MARK: - Placement

    private func place() {
        let center = savedCenter() ?? defaultCenter()
        let clamped = clamp(center)
        panel.setFrameOrigin(NSPoint(x: clamped.x - Self.panelSize.width / 2, y: clamped.y - Self.panelSize.height / 2))
    }

    private func saveCenter() {
        let frame = panel.frame
        let center = clamp(NSPoint(x: frame.midX, y: frame.midY))
        panel.setFrameOrigin(NSPoint(x: center.x - Self.panelSize.width / 2, y: center.y - Self.panelSize.height / 2))
        UserDefaults.standard.set(NSStringFromPoint(center), forKey: Self.centerKey)
    }

    /// A saved spot is used only while it is still on a screen, for example after a display is unplugged.
    private func savedCenter() -> NSPoint? {
        guard let text = UserDefaults.standard.string(forKey: Self.centerKey) else { return nil }
        let center = NSPointFromString(text)
        return NSScreen.screens.contains { $0.visibleFrame.contains(center) } ? center : nil
    }

    private func defaultCenter() -> NSPoint {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return NSPoint(x: frame.midX, y: frame.minY + Self.bottomGap + 17)
    }

    /// Keeps the idle capsule 12 pt inside the screen it is on.
    private func clamp(_ center: NSPoint) -> NSPoint {
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(center) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return center }
        let halfWidth: CGFloat = 26 + Self.edgeMargin
        let halfHeight: CGFloat = 17 + Self.edgeMargin
        return NSPoint(
            x: min(max(center.x, frame.minX + halfWidth), frame.maxX - halfWidth),
            y: min(max(center.y, frame.minY + halfHeight), frame.maxY - halfHeight))
    }
}
```

- [ ] **Step 5: Delete the old files**

```bash
cd /Users/abhishekananad/Documents/Chirp && git rm -q App/UI/Pill.swift App/UI/FloatingButton.swift
```

- [ ] **Step 6: Rewire `App/AppController.swift`**

Make these edits, in order.

6a. Replace the `status` property declaration

```swift
    private(set) var status: Status = .starting
```

with

```swift
    private(set) var status: Status = .starting {
        didSet { bar.setRest(restPhase) }
    }
```

6b. Remove the `windowText` property and its doc comment (two lines starting `/// The text box in the main window.` and `var windowText = ""`).

6c. Replace

```swift
    @ObservationIgnored let pill = PillController()
    @ObservationIgnored private lazy var floatingButton = FloatingButtonController(controller: self)
```

with

```swift
    @ObservationIgnored let bar = FloatingBarController()
    /// Input Monitoring was granted, but the event tap still failed. A relaunch fixes it.
    private(set) var hotkeyNeedsRestart = false
```

6d. In `init()`, replace

```swift
        recorder.onLevel = { [weak self] level in self?.pill.model.push(level) }
```

with

```swift
        recorder.onLevel = { [weak self] level in self?.bar.model.push(level) }
        bar.onClick = { [weak self] in self?.barClicked() }
```

6e. In `start()`, replace `floatingButton.setVisible(settings.showFloatingButton)` with `bar.setVisible(settings.showFloatingButton)`.

6f. Replace the whole `startHotkeyIfAllowed` method with

```swift
    func startHotkeyIfAllowed() {
        guard Permission.inputMonitoring.isGranted else { return }
        hotkeyNeedsRestart = !hotkey.start()
    }
```

6g. Replace the whole `toggleRecording(from:)` method with

```swift
    /// Click to start, click again to stop. Used by the Home record button.
    func toggleRecording(from source: RecordingSource) {
        switch status {
        case .recording: stopRecording()
        case .ready: startRecording(from: source)
        case .loadingModels: bar.flash("Getting ready · \(modelProgressText)", symbol: "arrow.down.circle", seconds: 2)
        case .failed: bar.flash("Could not load models", symbol: "exclamationmark.circle.fill", warning: true)
        default: break
        }
    }

    private func barClicked() {
        switch status {
        case .recording: stopRecording()
        case .ready: startRecording(from: .floatingButton)
        case .paused:
            togglePause()
            bar.flash("Mic on", symbol: "mic.fill", seconds: 1.5)
        case .loadingModels, .starting:
            bar.flash("Getting ready · \(modelProgressText)", symbol: "arrow.down.circle", seconds: 2)
        case .failed:
            bar.flash("Could not load models", symbol: "exclamationmark.circle.fill", warning: true)
        case .working:
            break
        }
    }
```

6h. In `startRecording(from:)`:

- replace the two `pill.flash` lines inside the first `guard` with
  ```swift
            if case .loadingModels = status { bar.flash("Getting ready · \(modelProgressText)", symbol: "arrow.down.circle", seconds: 2) }
            if case .failed = status { bar.flash("Could not load models", symbol: "exclamationmark.circle.fill", warning: true) }
  ```
- replace `pill.flash("Mic not allowed")` with `bar.flash("Microphone not allowed", symbol: "exclamationmark.circle.fill", warning: true)`
- replace `pill.flash("Mic not available")` with `bar.flash("Microphone not available", symbol: "exclamationmark.circle.fill", warning: true)`
- replace `if source != .window { pill.show(.recording) }` with
  ```swift
        bar.show(.listening(handsFree: source != .hotkey || machine.isHandsFree))
  ```

6i. In `stopRecording()`:

- replace `if source != .window { pill.show(.working) }` with `bar.show(.finishing)`
- replace `inserter: source == .window ? KeepInWindowInserter() as any TextInserter : PasteInserter(),` with `inserter: source == .window ? CopyInserter() as any TextInserter : PasteInserter(),`

6j. In `cancelRecording()`, replace `pill.hide()` with `bar.settle()`.

6k. Replace the whole `finish(_:source:)` method with

```swift
    private func finish(_ outcome: DictationOutcome, source: RecordingSource) {
        status = .ready
        recordingSource = nil
        switch outcome {
        case .noSpeech:
            bar.flash("Could not hear you", symbol: "exclamationmark.circle.fill", warning: true)
        case .transcriptionFailed:
            bar.flash("Could not transcribe", symbol: "exclamationmark.circle.fill", warning: true)
        case let .delivered(result):
            switch result.insert {
            case .pasted: bar.showPasted()
            case .copiedNoTextField: bar.flash("Copied · ⌘V to paste", symbol: "doc.on.clipboard")
            case .copiedNoPermission: bar.flash("Copied · allow Accessibility to paste", symbol: "doc.on.clipboard")
            }
            markDictionaryUsed(result.usedDictionaryEntryIDs)
            historyRevision += 1
        }
        // A model change made while dictating is applied now.
        if loadedEngine != settings.speechEngine || loadedCleanerID != settings.cleanupModelID {
            Task { await loadModels() }
        }
    }
```

6l. In `settingsChanged(from:)`, replace `floatingButton.setVisible(settings.showFloatingButton)` with `bar.setVisible(settings.showFloatingButton)`.

6m. Replace the whole `// MARK: - Display` section (from `var shouldShowSetup` to the end of `menuBarSymbol`) with

```swift
    var shouldShowSetup: Bool {
        switch status {
        case .loadingModels, .failed: true
        default: needsSetup
        }
    }

    /// Something the Home banner must show.
    var needsAttention: Bool {
        if case .failed = status { return true }
        return needsSetup
    }

    var statusText: String {
        if needsAttention, status != .recording, status != .working { return "Needs attention" }
        switch status {
        case .starting, .loadingModels: return "Getting ready"
        case .ready: return "Ready"
        case .recording: return "Listening"
        case .working: return "Finishing"
        case .paused: return "Mic is off"
        case .failed: return "Needs attention"
        }
    }

    /// The second half of the status line. Empty when there is nothing useful to add.
    var statusHint: String {
        switch status {
        case .ready: "Hold \(settings.triggerKey.displayName) in any app"
        case .loadingModels: modelProgressText
        default: ""
        }
    }

    var modelProgressText: String { "\(Int((modelProgress * 100).rounded()))%" }

    var statusColor: Color {
        switch status {
        case .ready: needsAttention ? .orange : .green
        case .recording: .red
        case .failed: .orange
        default: .secondary
        }
    }

    private var restPhase: BarModel.Phase {
        switch status {
        case .paused: .micOff
        case .starting, .loadingModels: .loading
        default: .idle
        }
    }

    var menuBarSymbol: String {
        switch status {
        case .starting, .loadingModels: "arrow.down.circle"
        case .ready: "waveform"
        case .recording: "waveform.circle.fill"
        case .working: "ellipsis.circle"
        case .paused: "pause.circle"
        case .failed: "exclamationmark.triangle"
        }
    }
}

/// Home recordings stay in Saywise: the text is copied, never pasted.
private struct CopyInserter: TextInserter {
    func insert(_ text: String) async -> InsertOutcome {
        await MainActor.run {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        return .copiedNoTextField
    }
}
```

and delete the old `KeepInWindowInserter` struct at the bottom of the file.

6n. Add `import SwiftUI` to the imports at the top of the file (for `Color`).

- [ ] **Step 7: Keep `MainView.swift` compiling until Task 5 removes it**

In `App/UI/MainView.swift`:
- replace `TextEditor(text: $controller.windowText)` with `TextEditor(text: .constant(""))`
- replace the two `Button("Copy") { copy(controller.windowText) }` / `Button("Clear") { controller.windowText = "" }` lines and their `.disabled` modifiers with nothing (delete those four lines).

- [ ] **Step 8: Build**

Run BUILD.
Expected: `** BUILD SUCCEEDED **`. If `onGeometryChange` is flagged as unavailable, the deployment target is wrong; it must be macOS 15 in `project.yml` (it is).

- [ ] **Step 9: Run and check the bar by hand**

Run RUN. Then:

1. The bar sits at the bottom center of the screen as a 52 pt dark capsule with a mic glyph.
2. Hover it: it brightens a little and grows to 1.03.
3. Hold Fn and speak: the capsule grows to 184 pt, a red dot pulses on the left, bars move with your voice, after one second a small "esc" shows on the right.
4. Let go: it shows a spinner and "Finishing", then a green check for a moment, then back to the mic.
5. Click the bar: it records with a red lock instead of the dot. Click again: it finishes.
6. Drag the bar to the right edge: it stays 12 pt inside. Quit and relaunch: it is still there.

If any of these fail, fix before committing.

- [ ] **Step 10: Commit**

```bash
cd /Users/abhishekananad/Documents/Chirp && git add -A App && git commit -m "Replace the pill and floating button with one floating bar"
```

---

### Task 5: One window with a sidebar

**Files:**
- Create: `App/UI/Shell/Page.swift`, `App/UI/Shell/RootView.swift`, `App/UI/Shell/Sidebar.swift`
- Modify: `App/UI/WindowCoordinator.swift`, `App/UI/MenuContent.swift`, `App/ChirpApp.swift`
- Delete: `App/UI/MainView.swift`

**Interfaces:**
- Consumes: `controller.statusText`, `statusHint`, `statusColor` from Task 4.
- Produces: `enum Page`, `@Observable final class Navigation { var page: Page; var historyFocus: HistoryEntry.ID? }`, `WindowCoordinator.showMain(page:focusEntry:)`, `WindowCoordinator.navigation`. `RootView` switches on `navigation.page`. Until Tasks 6 to 8 land, Home shows a placeholder and History and Settings show today's views.

- [ ] **Step 1: Create `App/UI/Shell/Page.swift`**

```swift
import ChirpCore
import Observation

enum Page: String, CaseIterable, Identifiable {
    case home, history, dictionary, snippets, appStyles, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .history: "History"
        case .dictionary: "Dictionary"
        case .snippets: "Snippets"
        case .appStyles: "App styles"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .history: "clock.arrow.circlepath"
        case .dictionary: "character.book.closed"
        case .snippets: "text.badge.plus"
        case .appStyles: "app.badge"
        case .settings: "gearshape"
        }
    }
}

/// Which page the main window shows. Owned by the window coordinator so the menu can change it.
@MainActor
@Observable
final class Navigation {
    var page: Page = .home
    /// Set by Home when it opens one entry in History. History clears it once it has scrolled there.
    var historyFocus: HistoryEntry.ID?
}
```

- [ ] **Step 2: Create `App/UI/Shell/Sidebar.swift`**

```swift
import SwiftUI

struct Sidebar: View {
    let controller: AppController
    @Bindable var navigation: Navigation

    var body: some View {
        List(selection: $navigation.page) {
            ForEach(Page.allCases) { page in
                Label(page.title, systemImage: page.symbol).tag(page)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 24) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 8) {
                StatusDot(color: controller.statusColor, pulses: controller.status == .recording)
                VStack(alignment: .leading, spacing: 1) {
                    Text(controller.statusText).font(.caption)
                    if !controller.statusHint.isEmpty {
                        Text(controller.statusHint).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
```

- [ ] **Step 3: Create `App/UI/Shell/RootView.swift`**

```swift
import SwiftUI

struct RootView: View {
    @Bindable var controller: AppController
    let navigation: Navigation
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationSplitView {
            Sidebar(controller: controller, navigation: navigation)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.2), value: navigation.page)
        }
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: 820, minHeight: 560)
        .onReceive(timer) { _ in controller.startHotkeyIfAllowed() }
    }

    @ViewBuilder private var page: some View {
        switch navigation.page {
        case .home:
            PageColumn(title: "Home") { Text("Coming next.").foregroundStyle(.secondary) }
        case .history:
            HistoryView(controller: controller)
        case .dictionary:
            PageColumn(title: "Dictionary") { DictionaryTab(controller: controller).frame(minHeight: 360) }
        case .snippets:
            PageColumn(title: "Snippets") { SnippetsTab(controller: controller).frame(minHeight: 360) }
        case .appStyles:
            PageColumn(title: "App styles") { AppStylesTab(controller: controller).frame(minHeight: 360) }
        case .settings:
            SettingsView(controller: controller)
        }
    }
}
```

- [ ] **Step 4: Rewrite `App/UI/WindowCoordinator.swift`**

```swift
import AppKit
import ChirpCore
import SwiftUI

/// Opens and reuses the main window and the setup window. They are plain AppKit windows hosting
/// SwiftUI views, because the app's only scene is the menu bar extra.
@MainActor
final class WindowCoordinator {
    static let shared = WindowCoordinator()

    var controller: AppController?
    let navigation = Navigation()
    private var windows: [String: NSWindow] = [:]

    func showMain(page: Page? = nil, focusEntry: HistoryEntry.ID? = nil) {
        guard let controller else { return }
        if let page { navigation.page = page }
        if let focusEntry { navigation.historyFocus = focusEntry }
        show("main", size: NSSize(width: 980, height: 640), minSize: NSSize(width: 820, height: 560), resizable: true) {
            RootView(controller: controller, navigation: navigation)
        }
    }

    func showHistory() { showMain(page: .history) }

    func showSettings() { showMain(page: .settings) }

    func showSetup() {
        guard let controller else { return }
        show("setup", size: NSSize(width: 480, height: 420), minSize: nil, resizable: false) {
            SetupView(controller: controller)
        }
    }

    private func show<Content: View>(
        _ id: String, size: NSSize, minSize: NSSize?, resizable: Bool, @ViewBuilder content: () -> Content
    ) {
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        if resizable { style.insert(.resizable) }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size), styleMask: style, backing: .buffered, defer: false)
        window.title = "Saywise"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content())
        window.setContentSize(size)
        if let minSize { window.contentMinSize = minSize }
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
```

- [ ] **Step 5: Rewrite `App/UI/MenuContent.swift`**

```swift
import AppKit
import SwiftUI

struct MenuContent: View {
    let controller: AppController

    var body: some View {
        Text(controller.statusText)
        Divider()
        Button("Open Saywise") { WindowCoordinator.shared.showMain(page: .home) }
            .keyboardShortcut("o")
        Button("History") { WindowCoordinator.shared.showHistory() }
        Button("Settings…") { WindowCoordinator.shared.showSettings() }
            .keyboardShortcut(",")
        Button(controller.status == .paused ? "Resume Saywise" : "Pause Saywise") { controller.togglePause() }
        if controller.shouldShowSetup {
            Button("Finish setup…") { WindowCoordinator.shared.showSetup() }
        }
        Divider()
        Button("Quit Saywise") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
```

- [ ] **Step 6: Delete `MainView.swift`**

```bash
cd /Users/abhishekananad/Documents/Chirp && git rm -q App/UI/MainView.swift
```

`App/ChirpApp.swift` calls `WindowCoordinator.shared.showMain()` with no arguments; that still compiles. No change there.

- [ ] **Step 7: Build and run**

Run BUILD, then RUN. Check:

1. One window, 980 × 640, no title text, traffic lights at the top left over the sidebar.
2. Sidebar lists Home, History, Dictionary, Snippets, App styles, Settings with icons. The bottom shows the status dot, "Ready" and "Hold Fn in any app".
3. Clicking each item switches the content. Home says "Coming next."
4. Menu bar: Open Saywise (⌘O) opens Home. History opens the History page. Settings… (⌘,) opens Settings.
5. Close the window and reopen it from the menu: it keeps its page.

- [ ] **Step 8: Commit**

```bash
cd /Users/abhishekananad/Documents/Chirp && git add -A App && git commit -m "Move the app into one window with a sidebar"
```

---

### Task 6: Home

**Files:**
- Create: `App/UI/Home/HomeModel.swift`, `App/UI/Home/HomeView.swift`, `App/UI/Home/TalkCard.swift`, `App/UI/Home/StatCard.swift`, `App/UI/Home/ActivityChart.swift`, `App/UI/Home/TopAppsCard.swift`, `App/UI/Home/RecentCard.swift`
- Modify: `App/UI/Shell/RootView.swift` (the `.home` case), `App/System/Permissions.swift` (add `bannerText` and `requestOrOpenSettings()`)

**Interfaces:**
- Consumes: `HistoryStore.stats`, `HistoryStats`, `Card`, `StatusDot`, `Banner`, `RecordButton`, `PageColumn`, `CountUpText`, `AppIcon`, `WaveView`, `controller.bar.model.levels`, `Navigation`.
- Produces: `HomeView(controller:navigation:)`, `Permission.bannerText`, `Permission.requestOrOpenSettings()`.

- [ ] **Step 1: Add to `App/System/Permissions.swift`**

Inside `enum Permission`, after `reason`, add:

```swift
    var bannerText: String {
        switch self {
        case .microphone: "Saywise needs the microphone to hear you."
        case .accessibility: "Saywise needs Accessibility to paste into other apps."
        case .inputMonitoring: "Saywise needs Input Monitoring to notice the Fn key."
        }
    }

    /// Asks the system when it still can; otherwise opens the right pane of System Settings.
    func requestOrOpenSettings() {
        switch self {
        case .microphone:
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined { request() } else { openSettings() }
        case .accessibility:
            request()
            openSettings()
        case .inputMonitoring:
            request()
            openSettings()
        }
    }
```

- [ ] **Step 2: Create `App/UI/Home/HomeModel.swift`**

```swift
import ChirpCore
import Foundation
import Observation

@MainActor
@Observable
final class HomeModel {
    var stats: HistoryStats?
    var recent: [HistoryEntry] = []
    /// Numbers count up once, on the first load, not on every refresh.
    var countedUp = false

    var lastEntry: HistoryEntry? { recent.first }

    func load(from history: HistoryStore?) async {
        guard let history else { return }
        stats = try? await history.stats()
        recent = (try? await history.recent(limit: 5)) ?? []
    }

    static func greeting(at date: Date = Date(), calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 0..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    static func wordsDetail(today: Int, yesterday: Int) -> (text: String, isUp: Bool?) {
        if yesterday == 0 { return (today == 0 ? "Start talking to see your numbers" : "First words today", nil) }
        let change = Int(((Double(today) - Double(yesterday)) / Double(yesterday) * 100).rounded())
        if change == 0 { return ("Same as yesterday", nil) }
        return (change > 0 ? "+\(change)% vs yesterday" : "−\(abs(change))% vs yesterday", change > 0)
    }

    static func timeSaved(seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }

    static func streak(days: Int) -> String { days == 1 ? "1 day" : "\(days) days" }
}
```

- [ ] **Step 3: Create `App/UI/Home/StatCard.swift`**

```swift
import SwiftUI

struct StatCard: View {
    let label: String
    let value: Double
    let format: (Double) -> String
    let detail: String
    var detailColor: Color = .secondary
    var animateOnAppear = true
    @State private var shown: Double = 0

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                CountUpText(value: shown, format: format)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .padding(.top, 2)
                Text(detail).font(.caption).foregroundStyle(detailColor)
            }
        }
        .onAppear {
            if animateOnAppear {
                withAnimation(.easeOut(duration: 0.6)) { shown = value }
            } else {
                shown = value
            }
        }
        .onChange(of: value) { shown = value }
    }
}
```

- [ ] **Step 4: Create `App/UI/Home/TalkCard.swift`**

```swift
import ChirpCore
import SwiftUI

struct TalkCard: View {
    let controller: AppController
    let lastEntry: HistoryEntry?
    let openEntry: (HistoryEntry.ID) -> Void
    @State private var hoveringLast = false
    @State private var copied = false

    var body: some View {
        Card {
            HStack(spacing: 20) {
                RecordButton(state: buttonState) { controller.toggleRecording(from: .window) }
                middle.frame(width: 200, alignment: .leading)
                Divider().frame(height: 72)
                last
            }
            .frame(height: 80)
        }
    }

    private var buttonState: RecordButton.State {
        switch controller.status {
        case .ready: .idle
        case .recording: .recording
        case .working: .working
        default: .disabled
        }
    }

    @ViewBuilder private var middle: some View {
        switch controller.status {
        case .recording:
            WaveView(levels: Array(controller.bar.model.levels.suffix(24)) + Array(repeating: 0, count: max(0, 24 - controller.bar.model.levels.count)))
                .foregroundStyle(.primary)
        case .working:
            caption("Finishing…")
        case .paused:
            caption("Turn the mic on to talk")
        case .starting, .loadingModels:
            VStack(alignment: .leading, spacing: 8) {
                caption("Getting ready…")
                ProgressView(value: controller.modelProgress).controlSize(.small)
                Text(controller.modelProgressText).font(.caption).foregroundStyle(.secondary)
            }
        case .failed:
            caption("Needs attention")
        case .ready:
            caption("Press to talk")
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.body).foregroundStyle(.secondary)
    }

    @ViewBuilder private var last: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Last dictation").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                if let lastEntry, hoveringLast {
                    Button {
                        copy(lastEntry.finalText)
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            copied = false
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Copy")
                }
            }
            if let lastEntry {
                Text(lastEntry.finalText).font(.body).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { openEntry(lastEntry.id) }
                Text("\(lastEntry.appName ?? "Unknown app") · \(lastEntry.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Your words will show up here.").font(.body).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { hoveringLast = $0 }
    }
}
```

- [ ] **Step 5: Create `App/UI/Home/ActivityChart.swift`**

```swift
import Charts
import ChirpCore
import SwiftUI

struct ActivityChart: View {
    let days: [HistoryStats.Day]
    @State private var hovered: Date?

    private var maxWords: Int { days.map(\.words).max() ?? 0 }

    var body: some View {
        Chart(days, id: \.date) { day in
            BarMark(x: .value("Day", day.date, unit: .day), y: .value("Words", day.words))
                .foregroundStyle(Color.accentColor.opacity(Calendar.current.isDateInToday(day.date) ? 1 : 0.5))
                .cornerRadius(4)
                .annotation(position: .top, spacing: 4) {
                    if let hovered, Calendar.current.isDate(hovered, inSameDayAs: day.date) {
                        Text("\(day.date.formatted(.dateTime.weekday(.abbreviated).day())) · \(day.words) words")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(1, maxWords))
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case let .active(point):
                            guard let plot = proxy.plotFrame else { return }
                            hovered = proxy.value(atX: point.x - geometry[plot].origin.x, as: Date.self)
                        case .ended:
                            hovered = nil
                        }
                    }
            }
        }
        .frame(height: 140)
        .overlay {
            if maxWords == 0 {
                Text("Start talking to see your numbers").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 6: Create `App/UI/Home/TopAppsCard.swift`**

```swift
import ChirpCore
import SwiftUI

struct TopAppsCard: View {
    let apps: [HistoryStats.AppWords]

    private var top: Int { apps.first?.words ?? 1 }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Top apps").font(.headline)
                if apps.isEmpty {
                    Text("No apps yet.").font(.body).foregroundStyle(.secondary)
                }
                ForEach(apps, id: \.name) { app in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            AppIcon(bundleID: app.bundleID)
                            Text(app.name).font(.body).lineLimit(1)
                            Spacer()
                            Text(app.words.formatted()).font(.callout).foregroundStyle(.secondary).monospacedDigit()
                        }
                        GeometryReader { geometry in
                            Capsule().fill(Color.accentColor.opacity(0.5))
                                .frame(width: geometry.size.width * CGFloat(app.words) / CGFloat(max(1, top)))
                        }
                        .frame(height: 3)
                        .padding(.leading, 30)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 7: Create `App/UI/Home/RecentCard.swift`**

```swift
import ChirpCore
import SwiftUI

struct RecentCard: View {
    let entries: [HistoryEntry]
    let openEntry: (HistoryEntry.ID) -> Void
    let seeAll: () -> Void
    @State private var hovered: HistoryEntry.ID?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Recent").font(.headline)
                    Spacer()
                    Button("See all", action: seeAll).buttonStyle(.link).font(.caption)
                }
                .padding(.bottom, 10)
                if entries.isEmpty {
                    Text("Nothing yet.").font(.body).foregroundStyle(.secondary)
                }
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { Divider() }
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.finalText).font(.body).lineLimit(1)
                            Text("\(entry.appName ?? "Unknown app") · \(entry.createdAt.formatted(.relative(presentation: .named)))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if hovered == entry.id {
                            Button { copy(entry.finalText) } label: { Image(systemName: "doc.on.doc") }
                                .buttonStyle(.borderless).foregroundStyle(.secondary).help("Copy")
                        }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { openEntry(entry.id) }
                    .onHover { hovered = $0 ? entry.id : nil }
                }
            }
        }
    }
}
```

- [ ] **Step 8: Create `App/UI/Home/HomeView.swift`**

```swift
import ChirpCore
import SwiftUI

struct HomeView: View {
    @Bindable var controller: AppController
    let navigation: Navigation
    @State private var model = HomeModel()
    @State private var missing: Permission?
    @State private var appeared = false
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        PageColumn {
            header
            if let banner { banner }
            TalkCard(controller: controller, lastEntry: model.lastEntry, openEntry: open)
                .fadeIn(appeared, delay: 0)
            statsRow.fadeIn(appeared, delay: 0.04)
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Last 14 days").font(.headline)
                    ActivityChart(days: stats.last14Days)
                }
            }
            .fadeIn(appeared, delay: 0.08)
            HStack(alignment: .top, spacing: 16) {
                TopAppsCard(apps: stats.topApps)
                RecentCard(entries: model.recent, openEntry: open) { navigation.page = .history }
            }
            .fadeIn(appeared, delay: 0.12)
        }
        .task {
            await model.load(from: controller.history)
            refreshPermissions()
            withAnimation(.easeOut(duration: 0.25)) { appeared = true }
        }
        .onChange(of: controller.historyRevision) {
            Task {
                await model.load(from: controller.history)
                model.countedUp = true
            }
        }
        .onReceive(timer) { _ in refreshPermissions() }
    }

    private var stats: HistoryStats { model.stats ?? HistoryStats.empty(now: Date(), calendar: .current) }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(HomeModel.greeting()).font(.largeTitle.bold())
                HStack(spacing: 8) {
                    StatusDot(color: controller.statusColor, pulses: controller.status == .recording)
                    Text(controller.statusHint.isEmpty ? controller.statusText : "\(controller.statusText) · \(controller.statusHint)")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("Mic", isOn: Binding(get: { controller.isMicOn }, set: { controller.setMicOn($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!(controller.status == .ready || controller.status == .paused))
                .padding(.top, 6)
        }
    }

    @ViewBuilder private var banner: Banner? {
        if case .failed = controller.status {
            Banner(text: "Saywise could not load its models.", button: "Try again") { Task { await controller.loadModels() } }
        } else if let missing {
            Banner(text: missing.bannerText, button: "Allow") { missing.requestOrOpenSettings() }
        }
    }

    private var statsRow: some View {
        let words = HomeModel.wordsDetail(today: stats.wordsToday, yesterday: stats.wordsYesterday)
        return HStack(spacing: 16) {
            StatCard(label: "Words today", value: Double(stats.wordsToday), format: { Int($0).formatted() },
                     detail: words.text, detailColor: words.isUp == true ? .green : .secondary, animateOnAppear: !model.countedUp)
            StatCard(label: "Time saved", value: stats.secondsSavedThisWeek, format: HomeModel.timeSaved(seconds:),
                     detail: "this week", animateOnAppear: !model.countedUp)
            StatCard(label: "Dictations", value: Double(stats.dictationsThisWeek), format: { Int($0).formatted() },
                     detail: "this week", animateOnAppear: !model.countedUp)
            StatCard(label: "Streak", value: Double(stats.streakDays), format: { HomeModel.streak(days: Int($0)) },
                     detail: "best \(stats.bestStreakDays)", animateOnAppear: !model.countedUp)
        }
    }

    private func open(_ id: HistoryEntry.ID) {
        navigation.historyFocus = id
        navigation.page = .history
    }

    private func refreshPermissions() {
        missing = Permission.allCases.first { !$0.isGranted }
    }
}

private extension View {
    /// Cards fade in with a short stagger the first time Home appears.
    func fadeIn(_ shown: Bool, delay: Double) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 6)
            .animation(.easeOut(duration: 0.25).delay(delay), value: shown)
    }
}
```

Note: `@ViewBuilder private var banner: Banner?` returns an optional view; SwiftUI accepts `if let banner { banner }` in the body. If the compiler rejects the optional `@ViewBuilder`, change it to a plain computed `var banner: Banner?` without the attribute and keep the `if/else if` returning values with `return`.

- [ ] **Step 9: Switch Home in `RootView`**

In `App/UI/Shell/RootView.swift` replace

```swift
        case .home:
            PageColumn(title: "Home") { Text("Coming next.").foregroundStyle(.secondary) }
```

with

```swift
        case .home:
            HomeView(controller: controller, navigation: navigation)
```

- [ ] **Step 10: Build and run**

Run BUILD, then RUN. Check:

1. Home shows the greeting, the status line, the mic switch, the Talk card, four stat cards, the chart, Top apps and Recent.
2. Numbers count up once when Home first appears.
3. Hover a chart bar: a small callout shows the day and the word count.
4. Click the record button, say a sentence, click stop: the bar shows Finishing then "Copied · ⌘V to paste", and "Last dictation" and Recent update. ⌘V in another app pastes the text.
5. Hold Fn in another app and dictate: Home's Words today grows after the paste.
6. Turn the mic switch off: the status says "Mic is off", the record button is grey, the bar dims. Turn it on again.
7. Click a Recent row: History opens.

- [ ] **Step 11: Commit**

```bash
cd /Users/abhishekananad/Documents/Chirp && git add -A App && git commit -m "Add the Home dashboard"
```

---

### Task 7: History page

**Files:**
- Modify: `App/UI/HistoryView.swift` (rewrite), `App/UI/Shell/RootView.swift` (pass the navigation)

**Interfaces:**
- Consumes: `Navigation.historyFocus`, `PageColumn`, `controller.history`, `controller.deleteHistoryEntry`, `controller.clearHistory`, the global `copy(_:)`.
- Produces: `HistoryView(controller:navigation:)`.

- [ ] **Step 1: Rewrite `App/UI/HistoryView.swift`**

```swift
import AppKit
import ChirpCore
import SwiftUI

struct HistoryView: View {
    let controller: AppController
    @Bindable var navigation: Navigation
    @State private var entries: [HistoryEntry] = []
    @State private var search = ""
    @State private var expanded: HistoryEntry.ID?
    @State private var confirmClear = false

    private struct DayGroup: Identifiable {
        let id: Date
        let title: String
        let entries: [HistoryEntry]
    }

    var body: some View {
        ScrollViewReader { proxy in
            PageColumn {
                header
                if entries.isEmpty {
                    empty
                } else {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            ForEach(group.entries) { entry in
                                HistoryRow(entry: entry, expanded: expanded == entry.id) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        expanded = expanded == entry.id ? nil : entry.id
                                    }
                                } delete: {
                                    Task { await delete(entry) }
                                }
                                .id(entry.id)
                            }
                        }
                    }
                }
            }
            .onChange(of: navigation.historyFocus, initial: true) { focus(with: proxy) }
            .onChange(of: entries.count) { focus(with: proxy) }
        }
        .task(id: search) { await reload() }
        .onChange(of: controller.historyRevision) { Task { await reload() } }
        .confirmationDialog("Delete all history?", isPresented: $confirmClear) {
            Button("Delete all", role: .destructive) { Task { await controller.clearHistory() } }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("History").font(.largeTitle.bold())
            Spacer()
            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            Menu {
                Button("Clear all…", role: .destructive) { confirmClear = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform").font(.system(size: 40)).foregroundStyle(.tertiary)
            Text(search.isEmpty ? "Your dictations will show up here." : "Nothing matches.")
                .font(.body).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    private var groups: [DayGroup] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.createdAt) }
        return byDay.keys.sorted(by: >).map { day in
            let title: String
            if calendar.isDateInToday(day) {
                title = "Today"
            } else if calendar.isDateInYesterday(day) {
                title = "Yesterday"
            } else {
                title = day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            }
            return DayGroup(id: day, title: title, entries: byDay[day] ?? [])
        }
    }

    private func focus(with proxy: ScrollViewProxy) {
        guard let id = navigation.historyFocus, entries.contains(where: { $0.id == id }) else { return }
        expanded = id
        proxy.scrollTo(id, anchor: .center)
        navigation.historyFocus = nil
    }

    private func reload() async {
        entries = (try? await controller.history?.recent(search: search)) ?? []
    }

    private func delete(_ entry: HistoryEntry) async {
        await controller.deleteHistoryEntry(entry)
        await reload()
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let expanded: Bool
    let toggle: () -> Void
    let delete: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.finalText).font(.body).lineLimit(expanded ? nil : 2)
                    Text("\(entry.appName ?? "Unknown app") · \(entry.createdAt.formatted(date: .omitted, time: .shortened)) · \(Int(entry.audioSeconds.rounded())) s")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if hovering || expanded {
                    Button { copy(entry.finalText) } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary).help("Copy")
                }
            }
            if expanded {
                HStack(alignment: .top, spacing: 12) {
                    textBox("Heard", entry.rawText)
                    textBox("Written", entry.finalText)
                }
                .padding(.top, 12)
                Text("\(entry.style) · \(entry.language) · \(entry.cleanup) · \(entry.insertOutcome) · speech \(entry.transcribeMs) ms · cleanup \(entry.cleanupMs) ms · paste \(entry.insertMs) ms")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(expanded ? Color(nsColor: .controlBackgroundColor) : (hovering ? Color.primary.opacity(0.04) : .clear)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator, lineWidth: expanded ? 0.5 : 0))
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy") { copy(entry.finalText) }
            Button("Delete", role: .destructive, action: delete)
        }
    }

    private func textBox(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button { copy(text) } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless).foregroundStyle(.secondary)
            }
            Text(text).font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
    }
}

@MainActor
func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}
```

- [ ] **Step 2: Pass the navigation in `RootView`**

In `App/UI/Shell/RootView.swift` replace `HistoryView(controller: controller)` with `HistoryView(controller: controller, navigation: navigation)`.

- [ ] **Step 3: Build and run**

Run BUILD, then RUN. Check:

1. History shows day groups: Today, Yesterday, then dates.
2. Click a row: it expands with "Heard" and "Written" boxes and one caption line. Click again: it collapses. Only one row is open at a time.
3. Search filters the list. Clearing the search shows everything again.
4. The ··· menu offers "Clear all…" with a confirmation.
5. From Home, click a Recent row: History opens with that row expanded and in view.
6. Right-click a row: Copy and Delete work.

- [ ] **Step 4: Commit**

```bash
cd /Users/abhishekananad/Documents/Chirp && git add -A App && git commit -m "Group history by day and expand rows in place"
```

---

### Task 8: Settings and list pages

**Files:**
- Modify: `App/UI/Settings/SettingsView.swift` (rewrite), `App/UI/Shell/RootView.swift` (the three list cases)
- Rename: `App/UI/Settings/ListTabs.swift` to `App/UI/Settings/ListPages.swift`, and the types inside to `DictionaryPage`, `SnippetsPage`, `AppStylesPage`
- Delete: `HistorySettingsTab` (its rows move into `SettingsView`)
- Modify: `App/UI/SetupView.swift` (`ModelStatusView` moves to `SettingsView.swift`; `SetupView` keeps using it)

**Interfaces:**
- Consumes: `PageColumn`, `controller.settings`, `controller.loadModels`, `controller.redownloadModels`, `controller.clearHistory`, `controller.modelProgressText`.
- Produces: `SettingsView(controller:)` (one page), `DictionaryPage`, `SnippetsPage`, `AppStylesPage`, `ModelStatusView` (in `SettingsView.swift`).

- [ ] **Step 1: Rename the list file and its types**

```bash
cd /Users/abhishekananad/Documents/Chirp && git mv App/UI/Settings/ListTabs.swift App/UI/Settings/ListPages.swift
```

Then in `ListPages.swift`:
- rename `struct DictionaryTab` to `struct DictionaryPage`, `struct SnippetsTab` to `struct SnippetsPage`, `struct AppStylesTab` to `struct AppStylesPage`.
- in `DictionaryPage` and `SnippetsPage`, delete the leading `Text("…").font(.callout).foregroundStyle(.secondary)` help line (the page title carries it now) and wrap the remaining `List` and `Button` in the existing `VStack(alignment: .leading)`, which stays.
- delete the whole `struct HistorySettingsTab` and everything in it.
- `AppStylesPage` keeps its `Form` with `.formStyle(.grouped)`.

- [ ] **Step 2: Rewrite `App/UI/Settings/SettingsView.swift`**

```swift
import AppKit
import ChirpCore
import SwiftUI

struct SettingsView: View {
    @Bindable var controller: AppController
    @State private var modelIDDraft = ""
    @State private var sizes: [(String, String)] = []
    @State private var confirmClear = false

    var body: some View {
        PageColumn(title: "Settings") {
            Form {
                Section("Talk") {
                    Picker("Talk key", selection: $controller.settings.triggerKey) {
                        ForEach(TriggerKey.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Toggle("Show floating bar", isOn: $controller.settings.showFloatingButton)
                    Toggle("Play sounds", isOn: $controller.settings.soundsEnabled)
                }
                Section("Language") {
                    Picker("Language", selection: $controller.settings.languageMode) {
                        Text("Auto detect").tag(LanguageMode.auto)
                        Text("English").tag(LanguageMode.english)
                        Text("Hindi / Hinglish").tag(LanguageMode.hindi)
                    }
                    Text("Hindi is always written in Roman letters, for example \"kal meeting hai\".")
                        .font(.callout).foregroundStyle(.secondary)
                    Picker("Speech engine", selection: $controller.settings.speechEngine) {
                        Text("Whisper large-v3-turbo").tag(SpeechEngine.whisper)
                        Text("Qwen3-ASR 0.6B (testing)").tag(SpeechEngine.qwen3ASR)
                    }
                }
                Section("Models") {
                    LabeledContent("Status") { ModelStatusView(controller: controller) }
                    TextField("Cleanup model", text: $modelIDDraft)
                    HStack {
                        Button("Apply") { controller.settings.cleanupModelID = modelIDDraft }
                            .disabled(modelIDDraft == controller.settings.cleanupModelID || modelIDDraft.isEmpty)
                        Button("Use default") { modelIDDraft = ChirpSettings.defaultCleanupModelID }
                    }
                    ForEach(sizes, id: \.0) { name, size in
                        LabeledContent(name, value: size)
                    }
                    HStack {
                        Button("Show in Finder") { NSWorkspace.shared.open(controller.paths.modelsDirectory) }
                        Button("Download again") { controller.redownloadModels() }
                    }
                }
                Section("History") {
                    Picker("Keep history", selection: $controller.settings.historyRetention) {
                        Text("Off").tag(HistoryRetention.off)
                        Text("7 days").tag(HistoryRetention.days7)
                        Text("30 days").tag(HistoryRetention.days30)
                        Text("Forever").tag(HistoryRetention.forever)
                    }
                    Toggle("Keep audio of the last 50 dictations", isOn: $controller.settings.keepAudio)
                    Button("Show audio folder") { NSWorkspace.shared.open(controller.paths.audioDirectory) }
                    Button("Delete all history…", role: .destructive) { confirmClear = true }
                }
                Section("General") {
                    Toggle("Start at login", isOn: $controller.settings.launchAtLogin)
                    if let error = controller.settingsError {
                        Text(error).foregroundStyle(.orange)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(maxWidth: 600)
        }
        .confirmationDialog("Delete all history?", isPresented: $confirmClear) {
            Button("Delete all", role: .destructive) { Task { await controller.clearHistory() } }
        } message: {
            Text("This cannot be undone.")
        }
        .onAppear {
            modelIDDraft = controller.settings.cleanupModelID
            sizes = Self.folderSizes(in: controller.paths.modelsDirectory)
        }
    }

    static func folderSizes(in directory: URL) -> [(String, String)] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.sorted().map { name in
            let url = directory.appendingPathComponent(name)
            var bytes: Int64 = 0
            let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey]
            if let files = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys) {
                for case let file as URL in files {
                    bytes += Int64((try? file.resourceValues(forKeys: Set(keys)).totalFileAllocatedSize) ?? 0)
                }
            }
            return (name, ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
        }
    }
}

struct ModelStatusView: View {
    let controller: AppController

    var body: some View {
        switch controller.status {
        case .loadingModels, .starting:
            HStack(spacing: 8) {
                ProgressView(value: controller.modelProgress).frame(width: 120)
                Text(controller.modelProgressText).font(.callout).foregroundStyle(.secondary).monospacedDigit()
            }
        case .failed:
            HStack(spacing: 8) {
                Label("Could not load", systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
                Button("Try again") { Task { await controller.loadModels() } }.controlSize(.small)
            }
        default:
            Label("Ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        }
    }
}
```

- [ ] **Step 3: Remove the old `ModelStatusView` from `App/UI/SetupView.swift`**

Delete the whole `struct ModelStatusView` at the bottom of `SetupView.swift`. `SetupView` still uses `ModelStatusView(controller:)`, which now lives in `SettingsView.swift`.

- [ ] **Step 4: Update the list cases in `RootView`**

Replace the three list cases with:

```swift
        case .dictionary:
            PageColumn(title: "Dictionary", help: "Words Saywise must spell exactly. \"Heard as\" lists what the speech model writes instead, separated by commas.") {
                DictionaryPage(controller: controller).frame(minHeight: 400)
            }
        case .snippets:
            PageColumn(title: "Snippets", help: "Say the trigger and Saywise types the text. Example: \"my email\".") {
                SnippetsPage(controller: controller).frame(minHeight: 400)
            }
        case .appStyles:
            PageColumn(title: "App styles", help: "How Saywise writes in each app.") {
                AppStylesPage(controller: controller).frame(minHeight: 400)
            }
```

- [ ] **Step 5: Build and run**

Run BUILD, then RUN. Check:

1. Settings is one page with Talk, Language, Models, History, General. No tab bar.
2. "Talk key" and "Show floating bar" labels. Turning "Show floating bar" off hides the bar; a Fn recording still shows it while it runs.
3. Models shows a green check and "Ready".
4. Dictionary, Snippets and App styles show a title and one help line above their lists.

- [ ] **Step 6: Commit**

```bash
cd /Users/abhishekananad/Documents/Chirp && git add -A App && git commit -m "Make Settings one page and give the list pages titles"
```

---

### Task 9: First run

**Files:**
- Create: `App/UI/OnboardingView.swift`
- Delete: `App/UI/SetupView.swift`
- Modify: `App/UI/WindowCoordinator.swift` (`showSetup` uses `OnboardingView`), `App/System/Permissions.swift` (`reason` strings), `App/ChirpApp.swift` (open setup only when needed)

**Interfaces:**
- Consumes: `Permission.isGranted`, `request()`, `openSettings()`, `controller.status`, `modelProgress`, `modelProgressText`, `hotkeyNeedsRestart`, `AppRelauncher.relaunch()`, `controller.loadModels()`.
- Produces: `OnboardingView(controller:)`.

- [ ] **Step 1: Shorten the reasons in `App/System/Permissions.swift`**

Replace the `reason` property body with:

```swift
    var reason: String {
        switch self {
        case .microphone: "So Saywise can hear you."
        case .accessibility: "So Saywise can paste into other apps."
        case .inputMonitoring: "So Saywise notices when you hold Fn."
        }
    }
```

- [ ] **Step 2: Create `App/UI/OnboardingView.swift`**

```swift
import AppKit
import ChirpCore
import SwiftUI

struct OnboardingView: View {
    enum Step: Hashable {
        case welcome
        case permission(Permission)
        case fnKey
        case download
        case done
    }

    let controller: AppController
    @State private var steps: [Step] = []
    @State private var index = 0
    @State private var granted = false
    @State private var showDetails = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private static let seenKey = "onboardingSeen"

    var body: some View {
        ZStack {
            if let step = steps[safe: index] {
                page(for: step)
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .frame(width: 480, height: 420)
        .overlay(alignment: .bottom) { dots.padding(.bottom, 18) }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: index)
        .onAppear(perform: buildSteps)
        .onReceive(timer) { _ in tick() }
        .onExitCommand { }
    }

    // MARK: - Steps

    private func buildSteps() {
        let firstRun = !UserDefaults.standard.bool(forKey: Self.seenKey)
        var list: [Step] = []
        if firstRun { list.append(.welcome) }
        list += Permission.allCases.filter { !$0.isGranted }.map { Step.permission($0) }
        if firstRun && controller.settings.triggerKey == .fn { list.append(.fnKey) }
        if !modelsReady { list.append(.download) }
        list.append(.done)
        steps = list
        index = 0
    }

    private var modelsReady: Bool {
        switch controller.status {
        case .ready, .paused, .recording, .working: true
        default: false
        }
    }

    private func advance() {
        granted = false
        showDetails = false
        if index + 1 < steps.count {
            index += 1
            if case .download = steps[index], modelsReady { advance() }
        }
    }

    private func tick() {
        controller.startHotkeyIfAllowed()
        guard let step = steps[safe: index] else { return }
        switch step {
        case let .permission(permission):
            if permission.isGranted && !granted {
                granted = true
                Task {
                    try? await Task.sleep(for: .seconds(0.6))
                    advance()
                }
            }
        case .download:
            if modelsReady { advance() }
        default:
            break
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        NSApp.keyWindow?.close()
        WindowCoordinator.shared.showMain(page: .home)
    }

    // MARK: - Pages

    @ViewBuilder private func page(for step: Step) -> some View {
        switch step {
        case .welcome:
            StepPage(symbol: "waveform", title: "Welcome to Saywise",
                     line: "Hold Fn, speak, let go. Your words appear where you type. English, Hindi, or both. Everything stays on this Mac.",
                     button: "Continue", action: advance)
        case let .permission(permission):
            StepPage(symbol: granted ? "checkmark.circle.fill" : symbol(for: permission),
                     symbolColor: granted ? .green : .accentColor,
                     title: permission.title,
                     line: needsRestart(permission) ? "Saywise needs a quick restart to use this." : permission.reason,
                     button: needsRestart(permission) ? "Restart Saywise" : "Allow") {
                if needsRestart(permission) { AppRelauncher.relaunch() } else { permission.requestOrOpenSettings() }
            }
        case .fnKey:
            StepPage(symbol: "globe", title: "One setting for Fn",
                     line: "By default Fn opens the emoji picker. Set \"Press 🌐 key to\" to \"Do Nothing\".",
                     button: "Open Keyboard Settings",
                     action: { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!) },
                     secondary: "Done, continue", secondaryAction: advance)
        case .download:
            downloadPage
        case .done:
            StepPage(symbol: "checkmark.circle.fill", symbolColor: .green, title: "You're set",
                     line: "Hold Fn in any app and start talking.", button: "Open Saywise", action: finish)
        }
    }

    private var downloadPage: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrow.down.circle").font(.system(size: 44)).foregroundStyle(Color.accentColor).padding(.bottom, 18)
            Text("Downloading models").font(.title2.weight(.semibold)).padding(.bottom, 8)
            if case let .failed(message) = controller.status {
                Text("The download stopped.").font(.body).foregroundStyle(.secondary).padding(.bottom, 20)
                Button("Try again") { Task { await controller.loadModels() } }.buttonStyle(.borderedProminent)
                Button(showDetails ? "Hide details" : "Details") { showDetails.toggle() }.buttonStyle(.link).font(.caption).padding(.top, 8)
                if showDetails {
                    Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)
                }
            } else {
                Text("About 4 GB, once. After this, Saywise never uses the network.")
                    .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 340).padding(.bottom, 24)
                ProgressView(value: controller.modelProgress).frame(width: 240)
                Text(controller.modelProgressText).font(.caption).foregroundStyle(.secondary).monospacedDigit().padding(.top, 6)
            }
        }
        .padding(40)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { i in
                Circle().fill(i == index ? Color.primary : Color.secondary.opacity(0.3)).frame(width: 6, height: 6)
            }
        }
    }

    private func symbol(for permission: Permission) -> String {
        switch permission {
        case .microphone: "mic.fill"
        case .accessibility: "accessibility"
        case .inputMonitoring: "keyboard"
        }
    }

    private func needsRestart(_ permission: Permission) -> Bool {
        permission == .inputMonitoring && permission.isGranted && controller.hotkeyNeedsRestart
    }
}

private struct StepPage: View {
    let symbol: String
    var symbolColor: Color = .accentColor
    let title: String
    let line: String
    let button: String
    let action: () -> Void
    var secondary: String?
    var secondaryAction: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: symbol).font(.system(size: 44)).foregroundStyle(symbolColor).padding(.bottom, 18)
                .contentTransition(.symbolEffect(.replace))
            Text(title).font(.title2.weight(.semibold)).padding(.bottom, 8)
            Text(line).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 340).padding(.bottom, 26)
            Button(button, action: action).buttonStyle(.borderedProminent).controlSize(.large)
            if let secondary {
                Button(secondary, action: secondaryAction).buttonStyle(.link).font(.callout).padding(.top, 10)
            }
        }
        .padding(40)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
```

- [ ] **Step 3: Delete `SetupView.swift` and point the coordinator at the new view**

```bash
cd /Users/abhishekananad/Documents/Chirp && git rm -q App/UI/SetupView.swift
```

In `App/UI/WindowCoordinator.swift`, inside `showSetup()`, replace `SetupView(controller: controller)` with `OnboardingView(controller: controller)`.

- [ ] **Step 4: Open setup only when needed in `App/ChirpApp.swift`**

Replace the body of `applicationDidFinishLaunching` with:

```swift
        WindowCoordinator.shared.controller = controller
        controller.start()
        if controller.needsSetup || controller.settingsError != nil || !UserDefaults.standard.bool(forKey: "onboardingSeen") {
            WindowCoordinator.shared.showSetup()
        } else {
            WindowCoordinator.shared.showMain()
        }
```

- [ ] **Step 5: Build and run the first-run flow**

Run BUILD. Then reset the one-time flag and run:

```bash
defaults delete dev.saywise.app onboardingSeen 2>/dev/null; open /Users/abhishekananad/Documents/Chirp/build/Build/Products/Debug/Saywise.app
```

Check:

1. A 480 × 420 window with "Welcome to Saywise", a waveform symbol, one line and a Continue button. Dots at the bottom.
2. Continue slides to the next step. With every permission already granted, the next step is "One setting for Fn", then "You're set".
3. "Open Saywise" closes setup and opens Home.
4. Relaunch: setup does not show again. Home opens.
5. Revoke Microphone in System Settings and relaunch: setup shows only the Microphone step and "You're set". Allow it: the step shows a green check and moves on by itself.

- [ ] **Step 6: Commit**

```bash
cd /Users/abhishekananad/Documents/Chirp && git add -A App && git commit -m "Replace setup with a stepped first run"
```

---

### Task 10: Final check and screenshots

**Files:**
- Create: `docs/design/screens/` with PNG files
- Modify: none in code unless a check fails

- [ ] **Step 1: Full build and tests**

Run BUILD and TEST. Expected: build succeeded, all tests pass.

- [ ] **Step 2: Walk the "done means" list from the spec**

Run RUN and check each line of spec § 11:

1. Home, History, Dictionary, Snippets, App styles and Settings open from the sidebar and from the menu bar.
2. A hotkey recording, a bar click recording and a Home button recording show the bar states in order: Listening, Finishing, then Pasted (green check) or Copied.
3. Home's "Words today" equals a hand count of the words in today's History rows.
4. Switch macOS to dark mode (System Settings > Appearance) and look at Home, History, Settings and the bar. Switch back.

- [ ] **Step 3: Save screenshots**

Create the folder and capture the main window and the bar. The script finds the window by owner name with `CGWindowListCopyWindowInfo` and captures it with `screencapture -l`.

```bash
mkdir -p /Users/abhishekananad/Documents/Chirp/docs/design/screens
cat > /tmp/winid.swift <<'EOF'
import CoreGraphics
import Foundation
let owner = CommandLine.arguments[1]
let minWidth = Double(CommandLine.arguments[2]) ?? 0
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
for w in list {
    guard w[kCGWindowOwnerName as String] as? String == owner,
          let bounds = w[kCGWindowBounds as String] as? [String: Double],
          (bounds["Width"] ?? 0) >= minWidth,
          let id = w[kCGWindowNumber as String] as? Int else { continue }
    print(id); break
}
EOF
cd /Users/abhishekananad/Documents/Chirp/docs/design/screens
# main window (width >= 800); switch pages by hand between captures, or via the menu bar
screencapture -o -l "$(swift /tmp/winid.swift Saywise 800)" home.png
```

Repeat with the History page open as `history.png`, Settings as `settings.png`, then capture the bar (width under 400) idle as `bar-idle.png`, while holding Fn as `bar-listening.png` (run the capture command in a second terminal while holding the key), and the first setup step as `setup-1.png`:

```bash
screencapture -o -l "$(swift /tmp/winid.swift Saywise 0)" bar-idle.png
```

If `swift /tmp/winid.swift` is slow, that is the compiler; it is fine.

- [ ] **Step 4: Commit**

```bash
cd /Users/abhishekananad/Documents/Chirp && git add docs/design/screens && git commit -m "Add screenshots of the new UI"
```

---

## Self-review against the spec

| Spec section | Task |
|---|---|
| § 3 look (window size, sidebar, cards, type, color, motion) | 3, 5, 6 |
| § 4.1 header, § 4.2 banner, § 4.3 Talk card, § 4.4 stats, § 4.5 activity, § 4.6 half cards, § 4.7 states | 6 (states through `statusText`/`statusColor` in 4) |
| § 5.1 History | 7 |
| § 5.2 list pages | 8 |
| § 5.3 Settings | 8 |
| § 5.4 menu | 5 |
| § 6 floating bar (shape, states, motion, WaveView) | 3, 4 |
| § 7 first run | 9 |
| § 8 HistoryStats | 1, 2 |
| § 9 code map | all |
| § 10 build notes | 4 (fixed-size panel, decision 1), 6 (chart hover, count-up, app icons) |
| § 11 done means | 10 |

Known gaps, accepted on purpose:

- The spec's "Loading" row in § 4.7 mentions a progress bar in the Talk card. It is there (Task 6, `TalkCard.middle`).
- The bar's "Copied" message for a Home recording reads "Copied · ⌘V to paste", the same as for a paste that found no text field. Both mean the same thing to the user.
