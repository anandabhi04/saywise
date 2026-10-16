# Saywise UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Saywise into one sidebar window with a Home dashboard, one dark-glass floating bar, and a stepped first run, as specified.

**Architecture:** `ChirpCore` gains one pure stats type computed from history rows. The app target replaces four windows with one `RootView` (sidebar + pages), replaces `FloatingButton` + `Pill` with `FloatingBar` (one non-activating panel), and rewrites setup as `OnboardingView`. `AppController` keeps the pipeline and only changes how it talks to the bar and what strings it exposes.

**Tech Stack:** Swift 5, SwiftUI, AppKit, Swift Charts, GRDB (already used), Swift Testing. macOS 15. No new dependencies.

**Spec:** `docs/specs/2026-10-17-saywise-ui-design.md`. Read it before each task. Section numbers below refer to it.

## Global Constraints

- macOS 15 minimum. SwiftUI + AppKit + Swift Charts only. No third-party UI libraries.
- Colors: system accent, system red (live), system green (good), system orange (warning). Nothing else.
- The floating bar panel must stay non-activating: `styleMask: [.nonactivatingPanel, .borderless]`, `canBecomeKey` and `canBecomeMain` return `false`.
- The bar is dark in both light and dark mode: `NSAppearance(named: .darkAqua)` on the panel only.
- Copy strings exactly as the spec writes them.
- Every task ends with: `swift test` green in `Packages/ChirpCore`, and the app target building. Build commands:

```bash
cd Packages/ChirpCore && swift test 2>&1 | tail -5
```

```bash
xcodegen generate && xcodebuild -project Chirp.xcodeproj -scheme Chirp -configuration Debug -derivedDataPath build/DerivedData -skipPackagePluginValidation -skipMacroValidation build 2>&1 | grep -E "error:|warning:.*App/|BUILD" | head -40
```

- Launch for a visual check: `open build/DerivedData/Build/Products/Debug/Chirp.app`. Screenshots go in `docs/design/screens/` (create the folder in Task 9).
- Commit after each task with the message given. Do not touch files a task does not list.

---

## File structure

| File | Responsibility |
|---|---|
| `Packages/ChirpCore/Sources/ChirpCore/Storage/HistoryStats.swift` | Pure stats from `[HistoryEntry]` + `HistoryStore.stats(now:calendar:)` |
| `Packages/ChirpCore/Tests/ChirpCoreTests/HistoryStatsTests.swift` | Tests for the above |
| `App/UI/Components/Card.swift` | Card container modifier |
| `App/UI/Components/StatusDot.swift` | 8 pt dot, optional pulse |
| `App/UI/Components/WaveView.swift` | Level bars, shared by bar and Talk card |
| `App/UI/Components/RecordButton.swift` | 64 pt record button with states |
| `App/UI/Components/Banner.swift` | Orange warning banner |
| `App/UI/FloatingBar.swift` | `BarModel`, `FloatingBarView` |
| `App/UI/FloatingBarPanel.swift` | Panel, host view (click vs drag), `FloatingBarController` |
| `App/UI/RootView.swift` | `Page` enum, `NavigationSplitView`, page switch |
| `App/UI/Sidebar.swift` | Sidebar list + status row |
| `App/UI/Home/HomeModel.swift` | Loads stats + recent, greeting, talk state |
| `App/UI/Home/HomeView.swift` | Home page layout |
| `App/UI/Home/TalkCard.swift`, `StatCard.swift`, `ActivityChart.swift`, `TopAppsCard.swift`, `RecentCard.swift` | One card each |
| `App/UI/HistoryView.swift` | Rewritten list with expand-in-place |
| `App/UI/Settings/SettingsView.swift` | One grouped form |
| `App/UI/Settings/ListPages.swift` | Dictionary, Snippets, App styles pages (renamed from `ListTabs.swift`) |
| `App/UI/OnboardingView.swift` | Stepped setup (replaces `SetupView.swift`) |
| `App/UI/WindowCoordinator.swift` | One main window + setup window |
| `App/UI/MenuContent.swift` | Menu items |
| `App/AppController.swift` | `bar` instead of `pill`, new strings |
| `App/System/Permissions.swift` | New `reason` strings |
| Deleted | `App/UI/MainView.swift`, `App/UI/FloatingButton.swift`, `App/UI/Pill.swift`, `App/UI/SetupView.swift`, `App/UI/Settings/ListTabs.swift` |

---

### Task 1: HistoryStats in ChirpCore (spec § 8)

**Files:**
- Create: `Packages/ChirpCore/Sources/ChirpCore/Storage/HistoryStats.swift`
- Modify: `Packages/ChirpCore/Sources/ChirpCore/Storage/HistoryStore.swift` (add one method at the end of the class)
- Test: `Packages/ChirpCore/Tests/ChirpCoreTests/HistoryStatsTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct HistoryStats: Equatable, Sendable {
      public struct Day: Equatable, Sendable { public var date: Date; public var words: Int }
      public struct AppWords: Equatable, Sendable, Identifiable {
          public var bundleID: String?; public var name: String; public var words: Int
          public var id: String { bundleID ?? name }
      }
      public var wordsToday: Int, wordsYesterday: Int, wordsThisWeek: Int, dictationsThisWeek: Int
      public var secondsSavedThisWeek: Double, streakDays: Int, bestStreakDays: Int
      public var last14Days: [Day], topApps: [AppWords]
      public static let empty: HistoryStats
      public static func compute(entries: [HistoryEntry], now: Date, calendar: Calendar) -> HistoryStats
      public static func wordCount(_ text: String) -> Int
  }
  extension HistoryStore { public func stats(now: Date = Date(), calendar: Calendar = .current) async throws -> HistoryStats }
  ```

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import ChirpCore

struct HistoryStatsTests {
    // Fixed clock: Thursday 2026-10-15 14:00 UTC. Week (ISO-like, Monday start) is Oct 12–18.
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }()
    let now = Date(timeIntervalSince1970: 1_792_072_800) // 2026-10-15T14:00:00Z

    func entry(_ text: String, daysAgo: Int, hour: Int = 10, app: String = "Notes", bundle: String? = "com.apple.Notes", audio: Double = 5) -> HistoryEntry {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let at = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return HistoryEntry(
            createdAt: at, appBundleID: bundle, appName: app, style: "document", language: "auto",
            audioSeconds: audio, rawText: text, finalText: text, cleanup: "used", insertOutcome: "pasted",
            transcribeMs: 1, cleanupMs: 1, insertMs: 1, totalMs: 3, audioFileName: nil)
    }

    @Test func emptyInputGivesZerosAndFourteenDays() {
        let s = HistoryStats.compute(entries: [], now: now, calendar: calendar)
        #expect(s == HistoryStats.empty.with14Days(endingOn: now, calendar: calendar))
        #expect(s.last14Days.count == 14)
        #expect(s.last14Days.allSatisfy { $0.words == 0 })
        #expect(s.last14Days.last?.date == calendar.startOfDay(for: now))
    }

    @Test func countsWordsBySplittingOnWhitespace() {
        #expect(HistoryStats.wordCount("kal  meeting hai\n5 baje") == 5)
        #expect(HistoryStats.wordCount("   ") == 0)
    }

    @Test func todayAndYesterdayAndWeek() {
        let s = HistoryStats.compute(entries: [
            entry("one two three", daysAgo: 0),
            entry("four five", daysAgo: 1),
            entry("six", daysAgo: 3),          // Monday Oct 12, in this week
            entry("seven eight", daysAgo: 4),  // Sunday Oct 11, last week
        ], now: now, calendar: calendar)
        #expect(s.wordsToday == 3)
        #expect(s.wordsYesterday == 2)
        #expect(s.wordsThisWeek == 6)
        #expect(s.dictationsThisWeek == 3)
        #expect(s.last14Days.last?.words == 3)
        #expect(s.last14Days[13 - 4].words == 2)
    }

    @Test func timeSavedNeverNegativeAndOnlyThisWeek() {
        // 40 words at 40 wpm = 60 s. Minus 10 s audio = 50 s saved.
        let forty = Array(repeating: "w", count: 40).joined(separator: " ")
        let s = HistoryStats.compute(entries: [
            entry(forty, daysAgo: 0, audio: 10),
            entry("slow", daysAgo: 1, audio: 30),      // 1.5 s typing - 30 s audio → 0
            entry(forty, daysAgo: 5, audio: 0),        // last week, ignored
        ], now: now, calendar: calendar)
        #expect(abs(s.secondsSavedThisWeek - 50) < 0.001)
    }

    @Test func streakCountsConsecutiveDaysEndingToday() {
        let s = HistoryStats.compute(entries: [
            entry("a", daysAgo: 0), entry("b", daysAgo: 1), entry("c", daysAgo: 2),
            entry("d", daysAgo: 4),
        ], now: now, calendar: calendar)
        #expect(s.streakDays == 3)
    }

    @Test func streakMayEndYesterdayWhenTodayIsEmpty() {
        let s = HistoryStats.compute(entries: [
            entry("b", daysAgo: 1), entry("c", daysAgo: 2),
        ], now: now, calendar: calendar)
        #expect(s.streakDays == 2)
    }

    @Test func streakIsZeroAfterAGap() {
        let s = HistoryStats.compute(entries: [entry("c", daysAgo: 2)], now: now, calendar: calendar)
        #expect(s.streakDays == 0)
        #expect(s.bestStreakDays == 1)
    }

    @Test func bestStreakIsLongestRun() {
        let s = HistoryStats.compute(entries: [
            entry("a", daysAgo: 0),
            entry("b", daysAgo: 10), entry("c", daysAgo: 11), entry("d", daysAgo: 12), entry("e", daysAgo: 13),
        ], now: now, calendar: calendar)
        #expect(s.streakDays == 1)
        #expect(s.bestStreakDays == 4)
    }

    @Test func topAppsThisWeekOrderedAndLimitedToFive() {
        var entries: [HistoryEntry] = []
        for (i, name) in ["A", "B", "C", "D", "E", "F"].enumerated() {
            entries.append(entry(Array(repeating: "w", count: i + 1).joined(separator: " "), daysAgo: 0, app: name, bundle: "app.\(name)"))
        }
        entries.append(entry("x x x x x x x x x x x x x x x x x x x x", daysAgo: 6, app: "Old", bundle: "app.Old")) // last week
        let s = HistoryStats.compute(entries: entries, now: now, calendar: calendar)
        #expect(s.topApps.map(\.name) == ["F", "E", "D", "C", "B"])
        #expect(s.topApps.first?.words == 6)
    }

    @Test func unknownAppIsNamedUnknownApp() {
        let s = HistoryStats.compute(entries: [entry("a b", daysAgo: 0, app: "", bundle: nil)], now: now, calendar: calendar)
        #expect(s.topApps.first?.name == "Unknown app")
    }

    @Test func storeStatsReadsRows() async throws {
        let store = try HistoryStore()
        try await store.save(entry("one two", daysAgo: 0))
        try await store.save(entry("three", daysAgo: 1))
        let s = try await store.stats(now: now, calendar: calendar)
        #expect(s.wordsToday == 2)
        #expect(s.wordsYesterday == 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Packages/ChirpCore && swift test --filter HistoryStatsTests 2>&1 | tail -5`
Expected: compile error, `HistoryStats` not found.

- [ ] **Step 3: Implement**

```swift
// Packages/ChirpCore/Sources/ChirpCore/Storage/HistoryStats.swift
import Foundation

public struct HistoryStats: Equatable, Sendable {
    public struct Day: Equatable, Sendable {
        public var date: Date
        public var words: Int
        public init(date: Date, words: Int) { self.date = date; self.words = words }
    }

    public struct AppWords: Equatable, Sendable, Identifiable {
        public var bundleID: String?
        public var name: String
        public var words: Int
        public var id: String { bundleID ?? name }
        public init(bundleID: String?, name: String, words: Int) {
            self.bundleID = bundleID; self.name = name; self.words = words
        }
    }

    /// Words per minute we assume for typing, to estimate time saved.
    public static let typingWordsPerMinute = 40.0

    public var wordsToday = 0
    public var wordsYesterday = 0
    public var wordsThisWeek = 0
    public var dictationsThisWeek = 0
    public var secondsSavedThisWeek = 0.0
    public var streakDays = 0
    public var bestStreakDays = 0
    public var last14Days: [Day] = []
    public var topApps: [AppWords] = []

    public static let empty = HistoryStats()

    public func with14Days(endingOn now: Date, calendar: Calendar) -> HistoryStats {
        var copy = self
        let today = calendar.startOfDay(for: now)
        copy.last14Days = (0..<14).reversed().map { offset in
            Day(date: calendar.date(byAdding: .day, value: -offset, to: today)!, words: 0)
        }
        return copy
    }

    public static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    public static func compute(entries: [HistoryEntry], now: Date, calendar: Calendar) -> HistoryStats {
        var stats = HistoryStats.empty.with14Days(endingOn: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        var dayIndex: [Date: Int] = [:]
        for (i, day) in stats.last14Days.enumerated() { dayIndex[day.date] = i }

        var wordsByDay: [Date: Int] = [:]
        var appWords: [String: AppWords] = [:]

        for entry in entries {
            let words = wordCount(entry.finalText)
            let day = calendar.startOfDay(for: entry.createdAt)
            wordsByDay[day, default: 0] += words
            if let i = dayIndex[day] { stats.last14Days[i].words += words }
            if day == today { stats.wordsToday += words }
            if day == yesterday { stats.wordsYesterday += words }
            if entry.createdAt >= weekStart {
                stats.wordsThisWeek += words
                stats.dictationsThisWeek += 1
                let typing = Double(words) / typingWordsPerMinute * 60
                stats.secondsSavedThisWeek += max(0, typing - entry.audioSeconds)
                let name = entry.appName.flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown app"
                let key = entry.appBundleID ?? name
                var app = appWords[key] ?? AppWords(bundleID: entry.appBundleID, name: name, words: 0)
                app.words += words
                appWords[key] = app
            }
        }

        stats.topApps = Array(appWords.values.sorted { $0.words != $1.words ? $0.words > $1.words : $0.name < $1.name }.prefix(5))

        // Streak: walk back from today (or yesterday when today is empty).
        let activeDays = Set(wordsByDay.filter { $0.value > 0 || entries.contains { e in calendar.startOfDay(for: e.createdAt) == $0.key } }.keys)
        var cursor = activeDays.contains(today) ? today : yesterday
        while activeDays.contains(cursor) {
            stats.streakDays += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }

        var best = 0
        var run = 0
        var previous: Date?
        for day in activeDays.sorted() {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        stats.bestStreakDays = best
        return stats
    }
}
```

Add to `HistoryStore` (after `purge`):

```swift
    /// Rows for the dashboard: the last 60 days, enough for the 14 day chart, this week and the streak.
    public func stats(now: Date = Date(), calendar: Calendar = .current) async throws -> HistoryStats {
        let since = calendar.date(byAdding: .day, value: -60, to: calendar.startOfDay(for: now)) ?? now
        let entries = try await db.read { db in
            try HistoryEntry.filter(Column("createdAt") >= since).fetchAll(db)
        }
        return HistoryStats.compute(entries: entries, now: now, calendar: calendar)
    }
```

Note: `activeDays` is "days with at least one entry". Simplify the filter to `Set(entries.map { calendar.startOfDay(for: $0.createdAt) })` if the test passes with that; it should.

- [ ] **Step 4: Run tests**

Run: `cd Packages/ChirpCore && swift test 2>&1 | tail -5`
Expected: all pass, including the 11 new tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/ChirpCore && git commit -m "Add HistoryStats for the dashboard"
```

---

### Task 2: Shared components (spec § 3, § 4.3, § 4.2, § 6.4)

**Files:**
- Create: `App/UI/Components/Card.swift`, `StatusDot.swift`, `WaveView.swift`, `RecordButton.swift`, `Banner.swift`

**Interfaces:**
- Produces:
  ```swift
  extension View { func card(padding: CGFloat = 20) -> some View }
  struct StatusDot: View { var color: Color; var pulsing: Bool = false }
  struct WaveView: View { var levels: [Float]; var barWidth: CGFloat; var minHeight: CGFloat = 4; var maxHeight: CGFloat }
  enum RecordButtonState { case idle, recording, working, disabled }
  struct RecordButton: View { var state: RecordButtonState; var action: () -> Void }
  struct Banner: View { var text: String; var buttonTitle: String; var action: () -> Void }
  ```

- [ ] **Step 1: Write the files**

```swift
// Card.swift
import SwiftUI

private struct CardModifier: ViewModifier {
    var padding: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5))
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View { modifier(CardModifier(padding: padding)) }
}
```

```swift
// StatusDot.swift
import SwiftUI

struct StatusDot: View {
    var color: Color
    var pulsing = false
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(pulsing && dim ? 0.4 : 1)
            .onChange(of: pulsing, initial: true) { _, on in
                guard on else { dim = false; return }
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}
```

```swift
// WaveView.swift
import SwiftUI

/// Bars from recorder levels. Height = min + min(1, level × 12) × (max − min).
struct WaveView: View {
    var levels: [Float]
    var barWidth: CGFloat
    var minHeight: CGFloat = 4
    var maxHeight: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
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

```swift
// RecordButton.swift
import SwiftUI

enum RecordButtonState: Equatable { case idle, recording, working, disabled }

struct RecordButton: View {
    var state: RecordButtonState
    var action: () -> Void
    @State private var hovering = false
    @State private var pressed = false
    @State private var breathe = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if state == .recording {
                    Circle().fill(.red.opacity(0.25))
                        .scaleEffect(breathe ? 1.18 : 1)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { breathe = true }
                        }
                        .onDisappear { breathe = false }
                }
                Circle().fill(fill)
                glyph
            }
            .frame(width: 64, height: 64)
            .scaleEffect(pressed ? 0.96 : (hovering && clickable ? 1.04 : 1))
            .animation(.easeOut(duration: 0.12), value: hovering)
            .animation(.easeOut(duration: 0.12), value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(!clickable)
        .onHover { hovering = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false })
    }

    private var clickable: Bool { state == .idle || state == .recording }

    private var fill: AnyShapeStyle {
        switch state {
        case .idle: AnyShapeStyle(.primary)
        case .recording: AnyShapeStyle(.red)
        case .working: AnyShapeStyle(.primary.opacity(0.6))
        case .disabled: AnyShapeStyle(.quaternary)
        }
    }

    @ViewBuilder private var glyph: some View {
        switch state {
        case .working:
            ProgressView().controlSize(.small).tint(.white)
        case .disabled:
            Image(systemName: "mic.fill").font(.system(size: 24, weight: .semibold)).foregroundStyle(.tertiary)
        case .idle:
            Image(systemName: "mic.fill").font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(nsColor: .windowBackgroundColor))
        case .recording:
            Image(systemName: "stop.fill").font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
        }
    }
}
```

```swift
// Banner.swift
import SwiftUI

struct Banner: View {
    var text: String
    var buttonTitle: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            Text(text).font(.callout)
            Spacer()
            Button(buttonTitle, action: action).buttonStyle(.bordered).controlSize(.small)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.orange.opacity(0.12)))
    }
}
```

- [ ] **Step 2: Build**

Run the xcodebuild command from Global Constraints. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add App/UI/Components && git commit -m "Add shared UI components"
```

---

### Task 3: The floating bar and controller wiring (spec § 6, § 4.3 last paragraph)

**Files:**
- Create: `App/UI/FloatingBar.swift`, `App/UI/FloatingBarPanel.swift`
- Delete: `App/UI/FloatingButton.swift`, `App/UI/Pill.swift`
- Modify: `App/AppController.swift`
- Modify: `App/UI/MainView.swift` only where it breaks the build (it is deleted in Task 4; a minimal fix is fine)

**Interfaces:**
- Produces:
  ```swift
  @MainActor @Observable final class BarModel {
      enum Phase: Equatable { case idle, listening(handsFree: Bool), finishing, pasted, copied, micOff, loading, message(String, isError: Bool) }
      var phase: Phase; var levels: [Float]   // 20 bars
      func push(_ level: Float)
  }
  @MainActor final class FloatingBarController {
      let model: BarModel
      init(controller: AppController)
      func setVisible(_ visible: Bool)
      func show(_ phase: BarModel.Phase)          // persistent until the next show
      func flash(_ phase: BarModel.Phase, for seconds: Double)  // then back to resting phase
      func rest()                                  // idle, micOff or loading, from controller.status
  }
  // AppController additions
  var statusHint: String        // "Hold Fn in any app" or ""
  var modelProgressText: String // "1.6 GB of 4.1 GB" or "42%"
  var isHandsFree: Bool
  ```
- Consumes: `WaveView`, `StatusDot` from Task 2.

- [ ] **Step 1: Write `FloatingBar.swift`**

```swift
import Observation
import SwiftUI

@MainActor
@Observable
final class BarModel {
    enum Phase: Equatable {
        case idle
        case listening(handsFree: Bool)
        case finishing
        case pasted
        case copied
        case micOff
        case loading
        case message(String, isError: Bool)
    }

    static let barCount = 20

    var phase: Phase = .idle
    var levels = Array(repeating: Float(0), count: barCount)
    var hovering = false

    func push(_ level: Float) {
        levels.removeFirst()
        levels.append(level)
    }

    func resetLevels() { levels = Array(repeating: 0, count: Self.barCount) }
}

struct FloatingBarView: View {
    let model: BarModel
    @State private var showEsc = false

    var body: some View {
        content
            .font(.system(size: 13, weight: .medium).monospacedDigit())
            .foregroundStyle(.white)
            .frame(height: 34)
            .frame(minWidth: 52)
            .padding(.horizontal, isCompact ? 0 : 14)
            .background(
                Capsule().fill(.black.opacity(model.hovering ? 0.42 : 0.3))
                    .overlay(Capsule().strokeBorder(.white.opacity(model.hovering ? 0.2 : 0.12), lineWidth: 0.5)))
            .opacity(model.phase == .micOff ? 0.7 : 1)
            .scaleEffect(model.hovering && isCompact ? 1.03 : 1)
            .animation(.easeOut(duration: 0.12), value: model.hovering)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.phase)
            .fixedSize()
            .help(model.phase == .idle ? "Talk · drag to move" : "")
            .onChange(of: model.phase, initial: true) { _, phase in
                showEsc = false
                if case .listening = phase {
                    Task { try? await Task.sleep(for: .seconds(1)); if case .listening = model.phase { withAnimation { showEsc = true } } }
                }
            }
    }

    private var isCompact: Bool {
        switch model.phase {
        case .idle, .pasted, .micOff, .loading: true
        default: false
        }
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .idle:
            Image(systemName: "mic.fill").font(.system(size: 14)).opacity(0.85).frame(width: 52)
        case let .listening(handsFree):
            HStack(spacing: 0) {
                if handsFree {
                    Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.red)
                } else {
                    StatusDot(color: .red, pulsing: true)
                }
                Spacer(minLength: 0)
                WaveView(levels: model.levels, barWidth: 2.5, maxHeight: 18)
                Spacer(minLength: 0)
                Text("esc").font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.5), lineWidth: 1))
                    .opacity(showEsc ? 0.5 : 0)
            }
            .frame(width: 184 - 28)
        case .finishing:
            HStack(spacing: 9) { ProgressView().controlSize(.small).tint(.white); Text("Finishing") }
        case .pasted:
            Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(.green).frame(width: 52)
        case .copied:
            HStack(spacing: 9) { Image(systemName: "doc.on.clipboard"); Text("Copied · ⌘V to paste") }
        case .micOff:
            Image(systemName: "mic.slash.fill").font(.system(size: 14)).opacity(0.5).frame(width: 52)
        case .loading:
            ProgressView().controlSize(.small).tint(.white).opacity(0.7).frame(width: 52)
        case let .message(text, isError):
            HStack(spacing: 9) {
                if isError { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange) }
                Text(text)
            }
        }
    }
}
```

- [ ] **Step 2: Write `FloatingBarPanel.swift`**

Keep the click-vs-drag host view from the old `FloatingButton.swift` as is (rename it `FloatingBarHostView`). Add hover tracking and the glass background.

```swift
import AppKit
import SwiftUI

/// Click toggles recording, drag moves the panel. AppKit handles the mouse so a drag never counts as a click.
private final class FloatingBarHostView: NSView {
    var onClick: () -> Void = {}
    var onMoved: (NSPoint) -> Void = { _ in }
    var onHover: (Bool) -> Void = { _ in }
    private var dragStart: NSPoint?
    private var windowStart: NSPoint?
    private var dragged = false
    private var tracking: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { onHover(true) }
    override func mouseExited(with event: NSEvent) { onHover(false) }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart, let windowStart, let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - dragStart.x, dy = now.y - dragStart.y
        if !dragged && hypot(dx, dy) < 4 { return }
        dragged = true
        window.setFrameOrigin(NSPoint(x: windowStart.x + dx, y: windowStart.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if dragged, let frame = window?.frame { onMoved(NSPoint(x: frame.midX, y: frame.midY)) } else { onClick() }
        dragStart = nil; windowStart = nil
    }
}

/// Never takes focus, so the text still pastes into the app the user was typing in.
private final class FloatingBarPanel: NSPanel {
    init(content: NSView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 52, height: 34),
                   styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isExcludedFromWindowsMenu = true
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = content
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingBarController {
    private static let centerKey = "floatingBarCenter"
    let model = BarModel()
    private let panel: FloatingBarPanel
    private let hosting: NSHostingView<FloatingBarView>
    private let glass = NSVisualEffectView()
    private weak var controller: AppController?
    private var flashTask: Task<Void, Never>?
    private var visible = false

    init(controller: AppController) {
        self.controller = controller
        let host = FloatingBarHostView(frame: NSRect(x: 0, y: 0, width: 52, height: 34))
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 17
        glass.layer?.masksToBounds = true
        glass.frame = host.bounds
        glass.autoresizingMask = [.width, .height]
        host.addSubview(glass)
        hosting = NSHostingView(rootView: FloatingBarView(model: model))
        hosting.frame = host.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.layer?.backgroundColor = .clear
        host.addSubview(hosting)
        panel = FloatingBarPanel(content: host)
        host.onClick = { [weak self] in self?.clicked() }
        host.onHover = { [weak self] in self?.model.hovering = $0 }
        host.onMoved = { [weak self] center in
            UserDefaults.standard.set(NSStringFromPoint(center), forKey: Self.centerKey)
            self?.layout()
        }
    }

    func setVisible(_ visible: Bool) {
        self.visible = visible
        if visible { rest(); layout(); panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    func show(_ phase: BarModel.Phase) {
        flashTask?.cancel()
        if case .listening = phase { model.resetLevels() }
        model.phase = phase
        layout()
        if visible || !isResting(phase) { panel.orderFrontRegardless() }
    }

    func flash(_ phase: BarModel.Phase, for seconds: Double) {
        show(phase)
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.rest()
        }
    }

    /// The bar's resting look follows the controller's status.
    func rest() {
        flashTask?.cancel()
        guard let controller else { return }
        switch controller.status {
        case .paused: model.phase = .micOff
        case .starting, .loadingModels: model.phase = .loading
        default: model.phase = .idle
        }
        layout()
        if !visible { panel.orderOut(nil) }
    }

    private func isResting(_ phase: BarModel.Phase) -> Bool {
        switch phase { case .idle, .micOff, .loading: true; default: false }
    }

    private func clicked() {
        guard let controller else { return }
        switch model.phase {
        case .copied, .message: rest()
        case .micOff:
            controller.setMicOn(true)
            flash(.message("Mic on", isError: false), for: 1.5)
        case .loading:
            flash(.message("Getting ready · \(controller.modelProgressText)", isError: false), for: 2)
        case .finishing, .pasted: break
        case .idle, .listening: controller.toggleRecording(from: .floatingButton)
        }
    }

    /// Resize around the saved center, kept 12 pt inside the screen. The frame is set without
    /// animation; SwiftUI animates the content.
    private func layout() {
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        let center = savedCenter() ?? defaultCenter()
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main else { return }
        let bounds = screen.visibleFrame.insetBy(dx: 12, dy: 12)
        var origin = NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
    }

    private func savedCenter() -> NSPoint? {
        guard let text = UserDefaults.standard.string(forKey: Self.centerKey) else { return nil }
        let center = NSPointFromString(text)
        return NSScreen.screens.contains { $0.visibleFrame.contains(center) } ? center : nil
    }

    private func defaultCenter() -> NSPoint {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return NSPoint(x: frame.midX, y: frame.minY + 20 + 17)
    }
}
```

- [ ] **Step 3: Rewire `AppController`**

Make these exact changes:

1. Replace `@ObservationIgnored let pill = PillController()` and the `floatingButton` line with:
   ```swift
   @ObservationIgnored private(set) lazy var bar = FloatingBarController(controller: self)
   ```
2. In `init`, `recorder.onLevel = { [weak self] level in self?.bar.model.push(level) }`.
3. In `start()`, `bar.setVisible(settings.showFloatingButton)`. In `settingsChanged`, same.
4. Add a `didSet` on `status` that calls `bar.rest()` when the new value is `.ready`, `.paused`, `.starting` or `.loadingModels` and the bar is not mid-flash. Simplest: in `togglePause()` and at the end of `loadModels()` (both the `.ready` and `.failed` exits) call `bar.rest()`.
5. `toggleRecording`: `.loadingModels` → `bar.flash(.message("Getting ready · \(modelProgressText)", isError: false), for: 2)`; `.failed` → `bar.flash(.message("Saywise could not load its models", isError: true), for: 3)`.
6. `startRecording`: the two guard flashes become `bar.flash(.message(...), isError: true), for: 3)` with texts "Getting ready", "Microphone not allowed", "Microphone not available". Replace `if source != .window { pill.show(.recording) }` with `bar.show(.listening(handsFree: isHandsFree))` for every source.
7. `stopRecording`: replace the pill line with `bar.show(.finishing)` for every source. Keep `KeepInWindowInserter` for `.window`.
8. `cancelRecording`: `bar.rest()`.
9. `finish`:
   ```swift
   case .noSpeech: bar.flash(.message("No speech heard", isError: true), for: 3)
   case .transcriptionFailed: bar.flash(.message("Could not hear you", isError: true), for: 3)
   case let .delivered(result):
       if source == .window {
           windowText = result.finalText
           NSPasteboard.general.clearContents()
           NSPasteboard.general.setString(result.finalText, forType: .string)
           bar.flash(.copied, for: 3)
       } else {
           switch result.insert {
           case .pasted: bar.flash(.pasted, for: 0.4)
           case .copiedNoTextField, .copiedNoPermission: bar.flash(.copied, for: 3)
           }
       }
   ```
10. Hands-free: add `var isHandsFree: Bool { machine.isHandsFree }`. When the state machine switches to hands-free mid-recording (double tap), the bar must update. In `handle(_:)`, after `machine.handle(event)`, if `status == .recording`, call `bar.show(.listening(handsFree: machine.isHandsFree))` only when the flag changed (keep a `lastHandsFree` private var). This does not reset levels because `show` resets only on entering `.listening` from another phase: change `show` to reset levels only when `model.phase` was not already `.listening`.
11. Display strings:
    ```swift
    var statusText: String {
        switch status {
        case .starting, .loadingModels: "Getting ready"
        case .ready: "Ready"
        case .recording: "Listening"
        case .working: "Finishing"
        case .paused: "Mic is off"
        case .failed: "Needs attention"
        }
    }
    var statusHint: String {
        status == .ready ? "Hold \(settings.triggerKey.displayName) in any app" : ""
    }
    /// "1.6 GB of 4.1 GB" when the loader reports bytes; otherwise a percent.
    var modelProgressText: String {
        if let bytes = modelBytes, bytes.total > 0 {
            let f = ByteCountFormatter(); f.countStyle = .file
            return "\(f.string(fromByteCount: bytes.done)) of \(f.string(fromByteCount: bytes.total))"
        }
        return "\(Int((modelProgress * 100).rounded()))%"
    }
    private(set) var modelBytes: (done: Int64, total: Int64)?  // nil today; the loader gives only a fraction
    var loadingDetail: String { if case let .loadingModels(m) = status { m } else { "" } }
    var failureDetail: String { if case let .failed(m) = status { m } else { "" } }
    ```
    `modelBytes` stays `nil` unless `EngineLoader` exposes bytes; do not change the engines package.
12. `menuBarSymbol`: keep.

- [ ] **Step 4: Delete the old files and fix the build**

```bash
git rm App/UI/FloatingButton.swift App/UI/Pill.swift
```
`MainView.swift` compiles against `controller.statusText` and `windowText`; it should still build. If `pill` is referenced anywhere else, replace with the bar equivalents above.

- [ ] **Step 5: Build and run**

Build. Launch the app. Check: bar appears bottom center, dark, 52 pt. Hold Fn: bar grows, red dot pulses, wave moves. Release: "Finishing", then green tick, then idle. Drag the bar; quit and relaunch; it stays where you left it. Click the bar while paused (Pause from the menu): "Mic on" shows and the mic turns on.

- [ ] **Step 6: Commit**

```bash
git add -A App && git commit -m "Replace the floating button and pill with one floating bar"
```

---

### Task 4: One window with a sidebar (spec § 3, § 5.4, § 9)

**Files:**
- Create: `App/UI/RootView.swift`, `App/UI/Sidebar.swift`
- Modify: `App/UI/WindowCoordinator.swift`, `App/UI/MenuContent.swift`, `App/ChirpApp.swift`
- Rename: `App/UI/Settings/ListTabs.swift` → `App/UI/Settings/ListPages.swift` (content unchanged in this task)
- Delete: `App/UI/MainView.swift`

**Interfaces:**
- Produces:
  ```swift
  enum Page: String, CaseIterable, Identifiable { case home, history, dictionary, snippets, appStyles, settings }
  struct RootView: View { init(controller: AppController, page: Binding<Page>, historyFocus: Binding<HistoryEntry.ID?>) }
  // WindowCoordinator
  func showMain(page: Page? = nil, focusingHistory id: HistoryEntry.ID? = nil)
  func showHistory() // = showMain(page: .history)
  func showSettings() // = showMain(page: .settings)
  ```
- Consumes: `HomeView` does not exist yet. For this task, the `.home` case shows `Text("Home").font(.largeTitle)`. Task 5 replaces it.

- [ ] **Step 1: Write `RootView.swift`**

```swift
import ChirpCore
import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case home, history, dictionary, snippets, appStyles, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"; case .history: "History"; case .dictionary: "Dictionary"
        case .snippets: "Snippets"; case .appStyles: "App styles"; case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"; case .history: "clock.arrow.circlepath"; case .dictionary: "character.book.closed"
        case .snippets: "text.badge.plus"; case .appStyles: "app.badge"; case .settings: "gearshape"
        }
    }
}

/// Holds the page across window close and reopen, so the menu can open History or Settings directly.
@MainActor @Observable final class RootState {
    var page: Page = .home
    var historyFocus: HistoryEntry.ID?
}

struct RootView: View {
    @Bindable var controller: AppController
    @Bindable var state: RootState

    var body: some View {
        NavigationSplitView {
            Sidebar(controller: controller, page: $state.page)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            ZStack {
                switch state.page {
                case .home: Text("Home").font(.largeTitle)
                case .history: HistoryView(controller: controller)
                case .dictionary: PageColumn(title: "Dictionary") { DictionaryTab(controller: controller) }
                case .snippets: PageColumn(title: "Snippets") { SnippetsTab(controller: controller) }
                case .appStyles: PageColumn(title: "App styles") { AppStylesTab(controller: controller) }
                case .settings: PageColumn(title: "Settings") { SettingsView(controller: controller) }
                }
            }
            .id(state.page)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: state.page)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: 820, minHeight: 560)
    }
}

/// The content column: title, optional help line, then the page, 760 pt wide and centered.
struct PageColumn<Content: View>: View {
    var title: String
    var help: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.largeTitle.bold())
                    if let help { Text(help).font(.callout).foregroundStyle(.secondary) }
                }
                content()
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(32)
            .padding(.top, 12)
        }
    }
}
```

- [ ] **Step 2: Write `Sidebar.swift`**

```swift
import SwiftUI

struct Sidebar: View {
    let controller: AppController
    @Binding var page: Page

    var body: some View {
        VStack(spacing: 0) {
            List(Page.allCases, selection: $page) { page in
                Label(page.title, systemImage: page.symbol).tag(page)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            HStack(spacing: 8) {
                StatusDot(color: statusColor, pulsing: controller.status == .recording)
                VStack(alignment: .leading, spacing: 1) {
                    Text(controller.statusText).font(.caption).fontWeight(.medium)
                    if !controller.statusHint.isEmpty {
                        Text(controller.statusHint).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
    }

    private var statusColor: Color {
        switch controller.status {
        case .ready: .green
        case .recording: .red
        case .failed: .orange
        default: Color(nsColor: .tertiaryLabelColor)
        }
    }
}
```

If the `selection` binding type-checks poorly with `Page`, use `List(selection: Binding<Page?>)` and map back with `?? .home`.

- [ ] **Step 3: Rewrite `WindowCoordinator.swift`**

```swift
import AppKit
import ChirpCore
import SwiftUI

/// One main window (sidebar + pages) and one setup window, both AppKit windows hosting SwiftUI,
/// because the app's only scene is the menu bar extra.
@MainActor
final class WindowCoordinator {
    static let shared = WindowCoordinator()

    var controller: AppController?
    let rootState = RootState()
    private var windows: [String: NSWindow] = [:]

    func showMain(page: Page? = nil, focusingHistory id: HistoryEntry.ID? = nil) {
        guard let controller else { return }
        if let page { rootState.page = page }
        if let id { rootState.page = .history; rootState.historyFocus = id }
        show("main", size: NSSize(width: 980, height: 640), minSize: NSSize(width: 820, height: 560)) {
            RootView(controller: controller, state: rootState)
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

    func closeSetup() { windows["setup"]?.close() }

    private func show<Content: View>(
        _ id: String, size: NSSize, minSize: NSSize?, resizable: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        var mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        if resizable { mask.insert(.resizable) }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: mask, backing: .buffered, defer: false)
        window.title = "Saywise"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = !resizable
        if let minSize { window.minSize = minSize }
        window.contentViewController = NSHostingController(rootView: content())
        window.setContentSize(size)
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
```

`SetupView` still exists until Task 8. `rootState` is reused so the page survives a close.

- [ ] **Step 4: Rewrite `MenuContent.swift`**

```swift
import AppKit
import SwiftUI

struct MenuContent: View {
    let controller: AppController

    var body: some View {
        Text(controller.statusText)
        Divider()
        Button("Open Saywise") { WindowCoordinator.shared.showMain() }.keyboardShortcut("o")
        Button("History") { WindowCoordinator.shared.showHistory() }
        Button("Settings…") { WindowCoordinator.shared.showSettings() }.keyboardShortcut(",")
        Button(controller.status == .paused ? "Resume Saywise" : "Pause Saywise") { controller.togglePause() }
        if controller.shouldShowSetup {
            Button("Finish setup…") { WindowCoordinator.shared.showSetup() }
        }
        Divider()
        Button("Quit Saywise") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
```

- [ ] **Step 5: Delete `MainView.swift`, rename `ListTabs.swift`**

```bash
git rm App/UI/MainView.swift && git mv App/UI/Settings/ListTabs.swift App/UI/Settings/ListPages.swift
```
`windowText` on the controller stays (Home uses it in Task 5).

- [ ] **Step 6: Build, run, check**

Build. Launch. The window is 980 × 640, hidden title, sidebar with six items, status row at the bottom. Menu bar: History opens the window on History. Close the window, choose Settings from the menu: it reopens on Settings.

- [ ] **Step 7: Commit**

```bash
git add -A App && git commit -m "Move all pages into one window with a sidebar"
```

---

### Task 5: Home (spec § 4)

**Files:**
- Create: `App/UI/Home/HomeModel.swift`, `HomeView.swift`, `TalkCard.swift`, `StatCard.swift`, `ActivityChart.swift`, `TopAppsCard.swift`, `RecentCard.swift`
- Modify: `App/UI/RootView.swift` (the `.home` case)

**Interfaces:**
- Consumes: `HistoryStats` (Task 1), `Card`, `StatusDot`, `WaveView`, `RecordButton`, `Banner` (Task 2), `controller.bar.model.levels`, `controller.statusText`, `statusHint`, `modelProgressText`, `windowText`, `historyRevision`, `toggleRecording(from: .window)`, `setMicOn`, `isMicOn`, `needsSetup`, `loadModels()`.
- Produces: `HomeView(controller:state:)`.

- [ ] **Step 1: `HomeModel.swift`**

```swift
import ChirpCore
import Observation
import SwiftUI

@MainActor @Observable
final class HomeModel {
    var stats = HistoryStats.empty.with14Days(endingOn: Date(), calendar: .current)
    var recent: [HistoryEntry] = []
    var hasLoadedOnce = false

    func reload(_ history: HistoryStore?) async {
        guard let history else { return }
        async let s = history.stats()
        async let r = history.recent(limit: 5)
        stats = (try? await s) ?? stats
        recent = (try? await r) ?? recent
        hasLoadedOnce = true
    }

    var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    var todayComparison: String {
        let today = stats.wordsToday, yesterday = stats.wordsYesterday
        if yesterday == 0 { return today == 0 ? "Start talking to see your numbers" : "First words today" }
        let change = Int(((Double(today) - Double(yesterday)) / Double(yesterday) * 100).rounded())
        if change == 0 { return "Same as yesterday" }
        return change > 0 ? "+\(change)% vs yesterday" : "−\(-change)% vs yesterday"
    }

    var timeSaved: String {
        let minutes = Int((stats.secondsSavedThisWeek / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    var streak: String { stats.streakDays == 1 ? "1 day" : "\(stats.streakDays) days" }
}

/// What the Talk card shows, derived from the controller.
enum TalkState: Equatable { case idle, recording, working, micOff, loading, blocked }

extension AppController {
    var talkState: TalkState {
        switch status {
        case .ready: .idle
        case .recording: recordingSource == .window ? .recording : .blocked
        case .working: recordingSource == .window ? .working : .blocked
        case .paused: .micOff
        case .starting, .loadingModels: .loading
        case .failed: .blocked
        }
    }

    /// The one banner Home shows, or nil.
    var homeBanner: (text: String, button: String, action: () -> Void)? {
        if case .failed = status {
            return ("Saywise could not load its models.", "Try again", { Task { await self.loadModels() } })
        }
        for permission in Permission.allCases where !permission.isGranted {
            let text = switch permission {
            case .microphone: "Saywise needs the microphone to hear you."
            case .accessibility: "Saywise needs Accessibility to paste into other apps."
            case .inputMonitoring: "Saywise needs Input Monitoring to notice the \(settings.triggerKey.displayName) key."
            }
            return (text, "Allow", { permission.request(); permission.openSettingsIfCannotAsk() })
        }
        return nil
    }
}
```

Add to `Permission` (in `Permissions.swift`): `func openSettingsIfCannotAsk()` that opens System Settings for `.accessibility` and `.inputMonitoring` (the system does not re-prompt those), and does nothing for `.microphone`.

- [ ] **Step 2: `HomeView.swift`**

```swift
import ChirpCore
import SwiftUI

struct HomeView: View {
    @Bindable var controller: AppController
    @Bindable var state: RootState
    @State private var model = HomeModel()
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let banner = controller.homeBanner {
                    Banner(text: banner.text, buttonTitle: banner.button, action: banner.action)
                }
                TalkCard(controller: controller, last: model.recent.first, open: openInHistory)
                HStack(spacing: 16) {
                    StatCard(label: "Words today", value: model.stats.wordsToday.formatted(), detail: model.todayComparison, animate: !appeared)
                    StatCard(label: "Time saved", value: model.timeSaved, detail: "this week", animate: false)
                    StatCard(label: "Dictations", value: model.stats.dictationsThisWeek.formatted(), detail: "this week", animate: !appeared)
                    StatCard(label: "Streak", value: model.streak, detail: "best \(model.stats.bestStreakDays)", animate: false)
                }
                ActivityChart(days: model.stats.last14Days)
                HStack(alignment: .top, spacing: 16) {
                    TopAppsCard(apps: model.stats.topApps)
                    RecentCard(entries: model.recent, open: openInHistory, seeAll: { state.page = .history })
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(32).padding(.top, 12)
        }
        .task { await model.reload(controller.history); withAnimation { appeared = true } }
        .onChange(of: controller.historyRevision) { Task { await model.reload(controller.history) } }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.greeting).font(.largeTitle.bold())
                HStack(spacing: 8) {
                    StatusDot(color: statusColor, pulsing: controller.status == .recording)
                    Text(controller.statusHint.isEmpty ? controller.statusText : "\(controller.statusText) · \(controller.statusHint)")
                        .font(.callout)
                    if case .loadingModels = controller.status { Text(controller.modelProgressText).font(.callout).foregroundStyle(.secondary) }
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { controller.isMicOn }, set: { controller.setMicOn($0) }))
                .toggleStyle(.switch).labelsHidden()
                .disabled(!(controller.status == .ready || controller.status == .paused))
        }
    }

    private var statusColor: Color {
        switch controller.status {
        case .ready: .green
        case .recording: .red
        case .failed: .orange
        default: Color(nsColor: .tertiaryLabelColor)
        }
    }

    private func openInHistory(_ entry: HistoryEntry) {
        state.historyFocus = entry.id
        state.page = .history
    }
}
```

The orange "Needs attention" dot when a permission is missing: `statusColor` returns `.orange` when `controller.homeBanner != nil`.

- [ ] **Step 3: `TalkCard.swift`**

```swift
import ChirpCore
import SwiftUI

struct TalkCard: View {
    @Bindable var controller: AppController
    var last: HistoryEntry?
    var open: (HistoryEntry) -> Void
    @State private var copied = false

    var body: some View {
        HStack(spacing: 20) {
            RecordButton(state: buttonState) { controller.toggleRecording(from: .window) }
            middle.frame(width: 200, alignment: .leading)
            Divider().frame(height: 72)
            lastText
        }
        .frame(height: 80)
        .card()
    }

    private var buttonState: RecordButtonState {
        switch controller.talkState {
        case .idle: .idle; case .recording: .recording; case .working: .working
        case .micOff, .loading, .blocked: .disabled
        }
    }

    @ViewBuilder private var middle: some View {
        switch controller.talkState {
        case .idle: Text("Press to talk").font(.body).foregroundStyle(.secondary)
        case .recording: WaveView(levels: controller.bar.model.levels, barWidth: 3, maxHeight: 24).foregroundStyle(.primary)
        case .working: Text("Finishing…").font(.body).foregroundStyle(.secondary)
        case .micOff: Text("Turn the mic on to talk").font(.body).foregroundStyle(.secondary)
        case .blocked: Text(" ").font(.body)
        case .loading:
            VStack(alignment: .leading, spacing: 6) {
                Text("Getting ready…").font(.body).foregroundStyle(.secondary)
                ProgressView(value: controller.modelProgress).controlSize(.small)
                Text(controller.modelProgressText).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var lastText: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Last dictation").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let last {
                    Button { copy(last.finalText); flashCopied() } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderless).foregroundStyle(.secondary).help("Copy")
                }
            }
            if let last {
                Text(last.finalText).font(.body).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { open(last) }
                Text("\(last.appName ?? "Unknown app") · \(last.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Your words will show up here.").font(.body).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func flashCopied() {
        copied = true
        Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
    }
}
```

`copy(_:)` is the global function already in `HistoryView.swift`; keep it there.

- [ ] **Step 4: `StatCard.swift`**

```swift
import SwiftUI

struct StatCard: View {
    var label: String
    var value: String
    var detail: String
    /// Count up from 0 on first appear when the value is a plain integer.
    var animate: Bool
    @State private var shown: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
            Text(displayValue)
                .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .onAppear {
            guard animate, let target = Int(value.filter(\.isNumber)) else { shown = -1; return }
            withAnimation(.easeOut(duration: 0.6)) { shown = Double(target) }
        }
    }

    private var displayValue: String {
        if shown < 0 { return value }
        guard let target = Int(value.filter(\.isNumber)), target > 0 else { return value }
        return Int(shown).formatted()
    }
}
```

- [ ] **Step 5: `ActivityChart.swift`**

```swift
import Charts
import ChirpCore
import SwiftUI

struct ActivityChart: View {
    var days: [HistoryStats.Day]
    @State private var hovered: HistoryStats.Day?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Last 14 days").font(.headline)
                Spacer()
                if let hovered {
                    Text("\(hovered.date.formatted(.dateTime.weekday(.wide).day().month())) · \(hovered.words) words")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ZStack {
                Chart(days, id: \.date) { day in
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Words", day.words))
                        .foregroundStyle(Color.accentColor.opacity(isToday(day) ? 1 : 0.5))
                        .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .chartYAxis(.hidden)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case let .active(point):
                                    let x = point.x - geo[proxy.plotFrame!].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        hovered = days.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
                                    }
                                case .ended: hovered = nil
                                }
                            }
                    }
                }
                if days.allSatisfy({ $0.words == 0 }) {
                    Text("Start talking to see your numbers").font(.callout).foregroundStyle(.secondary)
                }
            }
            .frame(height: 140)
        }
        .card()
    }

    private func isToday(_ day: HistoryStats.Day) -> Bool { Calendar.current.isDateInToday(day.date) }
}
```

- [ ] **Step 6: `TopAppsCard.swift` and `RecentCard.swift`**

```swift
// TopAppsCard.swift
import AppKit
import ChirpCore
import SwiftUI

struct TopAppsCard: View {
    var apps: [HistoryStats.AppWords]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top apps").font(.headline)
            if apps.isEmpty {
                Text("No apps yet.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(apps) { app in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(nsImage: AppIcons.icon(for: app.bundleID)).resizable().frame(width: 20, height: 20)
                        Text(app.name).font(.body)
                        Spacer()
                        Text(app.words.formatted()).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        Capsule().fill(Color.accentColor.opacity(0.5))
                            .frame(width: geo.size.width * CGFloat(app.words) / CGFloat(max(1, apps.first?.words ?? 1)))
                    }
                    .frame(height: 3).padding(.leading, 30)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// App icons by bundle id, cached. Unknown ids get the generic app icon.
@MainActor enum AppIcons {
    private static var cache: [String: NSImage] = [:]
    static func icon(for bundleID: String?) -> NSImage {
        let key = bundleID ?? ""
        if let hit = cache[key] { return hit }
        let image: NSImage
        if let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            image = NSWorkspace.shared.icon(for: .application)
        }
        cache[key] = image
        return image
    }
}
```

```swift
// RecentCard.swift
import ChirpCore
import SwiftUI

struct RecentCard: View {
    var entries: [HistoryEntry]
    var open: (HistoryEntry) -> Void
    var seeAll: () -> Void
    @State private var hovered: HistoryEntry.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent").font(.headline)
                Spacer()
                Button("See all", action: seeAll).buttonStyle(.link).font(.caption)
            }
            .padding(.bottom, 8)
            if entries.isEmpty {
                Text("Nothing yet.").font(.callout).foregroundStyle(.secondary).padding(.top, 4)
            }
            ForEach(entries) { entry in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.finalText).font(.body).lineLimit(1)
                        Text("\(entry.appName ?? "Unknown app") · \(entry.createdAt.formatted(.relative(presentation: .named)))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { copy(entry.finalText) } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                        .opacity(hovered == entry.id ? 1 : 0)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onHover { hovered = $0 ? entry.id : nil }
                .onTapGesture { open(entry) }
                if entry.id != entries.last?.id { Divider() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
```

- [ ] **Step 7: Wire `.home` in `RootView`**

Replace `case .home: Text("Home").font(.largeTitle)` with `case .home: HomeView(controller: controller, state: state)`.

- [ ] **Step 8: Build, run, check**

Home shows all blocks. Numbers match: count today's rows in History by hand and compare "Words today". Click the record button, speak, click stop: the bar shows Listening then Finishing then Copied; the text appears under "Last dictation" and the clipboard holds it. Click the last text: History opens (focus lands in Task 6). Turn the mic switch off: button greys out, "Turn the mic on to talk".

- [ ] **Step 9: Commit**

```bash
git add -A App && git commit -m "Add the Home dashboard"
```

---

### Task 6: History page (spec § 5.1)

**Files:**
- Modify: `App/UI/HistoryView.swift` (rewrite), `App/UI/RootView.swift` (pass `focus`)

**Interfaces:**
- Produces: `HistoryView(controller:focus: Binding<HistoryEntry.ID?>)`.

- [ ] **Step 1: Rewrite `HistoryView.swift`**

```swift
import AppKit
import ChirpCore
import SwiftUI

struct HistoryView: View {
    let controller: AppController
    @Binding var focus: HistoryEntry.ID?
    @State private var entries: [HistoryEntry] = []
    @State private var search = ""
    @State private var expanded: HistoryEntry.ID?
    @State private var confirmClear = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("History").font(.largeTitle.bold())
                        Spacer()
                        TextField("Search", text: $search).textFieldStyle(.roundedBorder).frame(width: 240)
                        Menu {
                            Button("Clear all…", role: .destructive) { confirmClear = true }
                        } label: { Image(systemName: "ellipsis.circle") }
                        .menuStyle(.borderlessButton).frame(width: 28)
                    }
                    .padding(.bottom, 8)
                    if entries.isEmpty {
                        emptyState
                    }
                    ForEach(groups, id: \.title) { group in
                        Text(group.title.uppercased())
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                            .kerning(0.6).padding(.top, 22).padding(.bottom, 6)
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
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(32).padding(.top, 12)
            }
            .onChange(of: focus, initial: true) { _, id in
                guard let id else { return }
                expanded = id
                focus = nil
                Task { await Task.yield(); withAnimation { proxy.scrollTo(id, anchor: .center) } }
            }
        }
        .confirmationDialog("Delete all history?", isPresented: $confirmClear) {
            Button("Delete all", role: .destructive) { Task { await controller.clearHistory() } }
        } message: { Text("This cannot be undone.") }
        .task(id: search) { await reload() }
        .onChange(of: controller.historyRevision) { Task { await reload() } }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform").font(.system(size: 40)).foregroundStyle(.tertiary)
            Text("Your dictations will show up here.").font(.body).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 120)
    }

    private struct Group { var title: String; var entries: [HistoryEntry] }

    private var groups: [Group] {
        let cal = Calendar.current
        var result: [Group] = []
        for entry in entries {
            let title: String
            if cal.isDateInToday(entry.createdAt) { title = "Today" }
            else if cal.isDateInYesterday(entry.createdAt) { title = "Yesterday" }
            else { title = entry.createdAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
            if result.last?.title == title { result[result.count - 1].entries.append(entry) }
            else { result.append(Group(title: title, entries: [entry])) }
        }
        return result
    }

    private func reload() async {
        entries = (try? await controller.history?.recent(search: search)) ?? []
        if let focus, entries.contains(where: { $0.id == focus }) { expanded = focus }
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
    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.finalText).font(.body).lineLimit(expanded ? nil : 2)
                    Text("\(entry.appName ?? "Unknown app") · \(entry.createdAt.formatted(date: .omitted, time: .shortened)) · \(Int(entry.audioSeconds.rounded())) s")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { copy(entry.finalText) } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless).foregroundStyle(.secondary).opacity(hovered || expanded ? 1 : 0).help("Copy")
            }
            if expanded {
                HStack(alignment: .top, spacing: 12) {
                    textBox("Heard", entry.rawText)
                    textBox("Written", entry.finalText)
                }
                .padding(.top, 12)
                Text("\(entry.style) · \(entry.language) · \(entry.cleanup) · \(entry.insertOutcome) · speech \(entry.transcribeMs) ms · cleanup \(entry.cleanupMs) ms · paste \(entry.insertMs) ms")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 10)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(expanded ? Color(nsColor: .controlBackgroundColor) : .clear))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(.separator, lineWidth: expanded ? 0.5 : 0))
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture(perform: toggle)
        .contextMenu {
            Button("Copy") { copy(entry.finalText) }
            Button("Delete", role: .destructive, action: delete)
        }
    }

    private func textBox(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                Spacer()
                Button { copy(text) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.borderless).foregroundStyle(.secondary)
            }
            Text(text).font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.quaternary))
    }
}

@MainActor
func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}
```

- [ ] **Step 2: Pass focus from `RootView`**

`case .history: HistoryView(controller: controller, focus: $state.historyFocus)`.

- [ ] **Step 3: Build, run, check**

History groups by day, rows expand in place with Heard/Written, only one open at a time. From Home, click a recent row: History opens with that row expanded and in view. Search filters. Clear all asks first. Empty search with no rows shows the waveform empty state.

- [ ] **Step 4: Commit**

```bash
git add -A App && git commit -m "Rewrite History as a grouped list that expands in place"
```

---

### Task 7: Settings and list pages (spec § 5.2, § 5.3)

**Files:**
- Modify: `App/UI/Settings/SettingsView.swift` (rewrite), `App/UI/Settings/ListPages.swift` (help lines move to `PageColumn`), `App/UI/RootView.swift` (help strings), `App/UI/SetupView.swift` (`ModelStatusView` only; it moves into `SettingsView.swift`)

- [ ] **Step 1: Rewrite `SettingsView.swift`**

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
                TextField("Cleanup model", text: $modelIDDraft, prompt: Text("Hugging Face id"))
                HStack {
                    Button("Apply") { controller.settings.cleanupModelID = modelIDDraft }
                        .disabled(modelIDDraft == controller.settings.cleanupModelID || modelIDDraft.isEmpty)
                    Button("Use default") { modelIDDraft = ChirpSettings.defaultCleanupModelID }
                }
                ForEach(sizes, id: \.0) { name, size in LabeledContent(name, value: size) }
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
                if let error = controller.settingsError { Text(error).foregroundStyle(.orange) }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .confirmationDialog("Delete all history?", isPresented: $confirmClear) {
            Button("Delete all", role: .destructive) { Task { await controller.clearHistory() } }
        } message: { Text("This cannot be undone.") }
        .onAppear {
            modelIDDraft = controller.settings.cleanupModelID
            sizes = Self.folderSizes(in: controller.paths.modelsDirectory)
        }
    }

    static func folderSizes(in directory: URL) -> [(String, String)] { /* unchanged from the old ModelsTab */ }
}

struct ModelStatusView: View {
    let controller: AppController

    var body: some View {
        switch controller.status {
        case .loadingModels:
            VStack(alignment: .trailing, spacing: 4) {
                ProgressView(value: controller.modelProgress).frame(width: 160)
                Text(controller.modelProgressText).font(.caption).foregroundStyle(.secondary)
            }
        case .failed:
            HStack(spacing: 8) {
                Label("Could not load", systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
                Button("Try again") { Task { await controller.loadModels() } }.controlSize(.small)
            }
        case .starting:
            Text("Starting…").foregroundStyle(.secondary)
        default:
            Label("Ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        }
    }
}
```

Copy `folderSizes` from the old `ModelsTab` as is. Remove `ModelStatusView` and `HistorySettingsTab` from the old files. `scrollDisabled(true)` is because `PageColumn` already scrolls; if the form clips, remove it and give the form a fixed height instead.

- [ ] **Step 2: List pages**

In `ListPages.swift`, remove the first `Text(...)` help line from `DictionaryTab` and `SnippetsTab`. In `RootView`, pass them as `help:`:

- Dictionary: `Words Saywise must spell exactly. "Heard as" lists what the speech model writes instead, separated by commas.`
- Snippets: `Say the trigger and Saywise types the text. Example: "my email".`
- App styles: `Pick a writing style per app. Browser title rules win inside browsers.`
- Settings: no help line.

Give each `List` in the two list pages `.frame(minHeight: 320)` and `.scrollContentBackground(.hidden)` with `.card(padding: 0)` so it reads as a card. `AppStylesTab` keeps its grouped form with `.scrollContentBackground(.hidden)` and `.scrollDisabled(true)`.

- [ ] **Step 3: Build, run, check**

Settings is one page with five sections. Models shows the green check. Dictionary, Snippets, App styles show a title, a help line, and their editors. Adding and deleting rows still works.

- [ ] **Step 4: Commit**

```bash
git add -A App && git commit -m "Flatten Settings into one page and frame the list pages"
```

---

### Task 8: First run as steps (spec § 7)

**Files:**
- Create: `App/UI/OnboardingView.swift`
- Delete: `App/UI/SetupView.swift`
- Modify: `App/System/Permissions.swift` (`reason` strings), `App/UI/WindowCoordinator.swift` (`showSetup` uses `OnboardingView`), `App/ChirpApp.swift` (no change expected), `App/AppController.swift` (`loadModels` failure still calls `showSetup()`; keep)

**Interfaces:**
- Produces: `OnboardingView(controller:)`.
- Consumes: `Permission`, `AppRelauncher`, `controller.status`, `modelProgress`, `modelProgressText`, `failureDetail`, `loadModels()`, `startHotkeyIfAllowed()`, `WindowCoordinator.shared.closeSetup()`, `showMain()`.

- [ ] **Step 1: Permission reasons**

```swift
    var reason: String {
        switch self {
        case .microphone: "So Saywise can hear you."
        case .accessibility: "So Saywise can paste into other apps."
        case .inputMonitoring: "So Saywise notices when you hold Fn."
        }
    }

    /// The system does not ask twice for these two, so the step opens System Settings instead.
    func openSettingsIfCannotAsk() {
        if self != .microphone { openSettings() }
    }
```

(`openSettingsIfCannotAsk` was added in Task 5; keep one copy.)

- [ ] **Step 2: `OnboardingView.swift`**

```swift
import AppKit
import SwiftUI

struct OnboardingView: View {
    let controller: AppController
    @State private var steps: [Step] = []
    @State private var index = 0
    @State private var justGranted = false
    @State private var needsRestart = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Step: Equatable {
        case welcome, permission(Permission), fnKey, download, done
    }

    var body: some View {
        ZStack {
            if steps.indices.contains(index) {
                page(for: steps[index])
                    .id(index)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: index)
        .frame(width: 480, height: 420)
        .overlay(alignment: .bottom) {
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { i in
                    Circle().fill(i == index ? Color.primary : Color(nsColor: .tertiaryLabelColor)).frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 18)
        }
        .onAppear { steps = Self.buildSteps(controller: controller); index = 0 }
        .onReceive(timer) { _ in tick() }
        .onExitCommand { }  // Esc does nothing here.
    }

    static func buildSteps(controller: AppController) -> [Step] {
        var steps: [Step] = [.welcome]
        for p in [Permission.microphone, .inputMonitoring, .accessibility] where !p.isGranted { steps.append(.permission(p)) }
        if controller.settings.triggerKey == .fn { steps.append(.fnKey) }
        switch controller.status {
        case .ready, .paused, .recording, .working: break
        default: steps.append(.download)
        }
        steps.append(.done)
        return steps
    }

    @ViewBuilder private func page(for step: Step) -> some View {
        switch step {
        case .welcome:
            StepPage(symbol: "waveform", title: "Welcome to Saywise",
                     line: "Hold Fn, speak, let go. Your words appear where you type. English, Hindi, or both. Everything stays on this Mac.",
                     button: "Continue", action: next)
        case let .permission(p):
            StepPage(symbol: symbol(for: p), title: p.title, line: p.reason,
                     button: needsRestart && p == .inputMonitoring ? "Restart Saywise" : "Allow",
                     secondLine: needsRestart && p == .inputMonitoring ? "Saywise needs a quick restart to use this." : nil,
                     granted: justGranted) {
                if needsRestart && p == .inputMonitoring { AppRelauncher.relaunch(); return }
                p.request(); p.openSettingsIfCannotAsk()
            }
        case .fnKey:
            StepPage(symbol: "globe", title: "One setting for Fn",
                     line: "By default Fn opens the emoji picker. Set \"Press 🌐 key to\" to \"Do Nothing\".",
                     button: "Open Keyboard Settings", secondaryButton: "Done, continue", secondaryAction: next) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
            }
        case .download:
            DownloadStep(controller: controller)
        case .done:
            StepPage(symbol: "checkmark.circle.fill", symbolColor: .green, title: "You're set",
                     line: "Hold Fn in any app and start talking.", button: "Open Saywise") {
                WindowCoordinator.shared.closeSetup()
                WindowCoordinator.shared.showMain()
            }
        }
    }

    private func symbol(for p: Permission) -> String {
        switch p { case .microphone: "mic.fill"; case .inputMonitoring: "keyboard"; case .accessibility: "accessibility" }
    }

    private func next() {
        justGranted = false
        if index + 1 < steps.count { index += 1 }
    }

    /// Once a second: move past a granted permission, past a finished download, and detect the restart case.
    private func tick() {
        guard steps.indices.contains(index) else { return }
        switch steps[index] {
        case let .permission(p) where p.isGranted:
            if p == .inputMonitoring {
                controller.startHotkeyIfAllowed()
                if !controller.hotkeyIsRunning { needsRestart = true; return }
            }
            guard !justGranted else { return }
            justGranted = true
            Task { try? await Task.sleep(for: .seconds(0.6)); next() }
        case .download:
            switch controller.status {
            case .ready, .paused: next()
            default: break
            }
        default: break
        }
    }
}

private struct StepPage: View {
    var symbol: String
    var symbolColor: Color = .accentColor
    var title: String
    var line: String
    var button: String
    var secondLine: String? = nil
    var secondaryButton: String? = nil
    var secondaryAction: (() -> Void)? = nil
    var granted = false
    var action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Image(systemName: symbol).font(.system(size: 44)).foregroundStyle(symbolColor).opacity(granted ? 0 : 1)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(.green).opacity(granted ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.2), value: granted)
            .padding(.bottom, 18)
            Text(title).font(.title2.weight(.semibold)).padding(.bottom, 8)
            Text(line).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 340)
            if let secondLine {
                Text(secondLine).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 6)
            }
            Button(button, action: action).buttonStyle(.borderedProminent).controlSize(.large).padding(.top, 26)
            if let secondaryButton, let secondaryAction {
                Button(secondaryButton, action: secondaryAction).buttonStyle(.link).padding(.top, 10)
            }
            Spacer()
        }
        .padding(40)
    }
}

private struct DownloadStep: View {
    let controller: AppController
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "arrow.down.circle").font(.system(size: 44)).foregroundStyle(Color.accentColor).padding(.bottom, 18)
            Text("Downloading models").font(.title2.weight(.semibold)).padding(.bottom, 8)
            Text("About 4 GB, once. After this, Saywise never uses the network.")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 340)
            Group {
                if case .failed = controller.status {
                    VStack(spacing: 8) {
                        Text("The download stopped.").font(.callout)
                        Button("Try again") { Task { await controller.loadModels() } }.buttonStyle(.borderedProminent)
                        Button(showDetails ? "Hide details" : "Details") { showDetails.toggle() }.buttonStyle(.link).font(.caption)
                        if showDetails {
                            Text(controller.failureDetail).font(.caption).foregroundStyle(.secondary)
                                .textSelection(.enabled).frame(maxWidth: 360)
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        ProgressView(value: controller.modelProgress).frame(width: 260)
                        Text(controller.modelProgressText).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 26)
            Spacer()
        }
        .padding(40)
    }
}
```

Add to `AppController`: `var hotkeyIsRunning: Bool { hotkey.isRunning }`. If `HotkeyMonitor` has no such flag, add `private(set) var isRunning = false` set to `true` when the event tap is created successfully and `false` when it fails.

- [ ] **Step 3: Wire and delete**

In `WindowCoordinator.showSetup`, host `OnboardingView(controller: controller)`. The setup window must not be resizable (already set in Task 4).

```bash
git rm App/UI/SetupView.swift
```

In `AppDelegate.applicationDidFinishLaunching`, keep: show main, then show setup when `needsSetup` or a settings error. Also show setup when models are not loaded on first launch: `controller.shouldShowSetup`.

- [ ] **Step 4: Build, run, check**

Run with Input Monitoring removed in System Settings for Saywise: setup opens with Welcome, then Input Monitoring. Grant it: green check, moves on. The dots at the bottom track the step. "You're set" opens the main window and closes setup. Esc does nothing.

- [ ] **Step 5: Commit**

```bash
git add -A App && git commit -m "Rewrite setup as one step per page"
```

---

### Task 9: Polish, screenshots, docs (spec § 11)

**Files:**
- Create: `docs/design/screens/` with PNGs
- Modify: `docs/specs/2026-10-17-saywise-ui-design.md` (Status line → "built"), `docs/design/saywise-ui.md` (add "Replaced by …" at the top, or delete it)

- [ ] **Step 1: Dark mode pass**

Switch the system to dark (System Settings > Appearance). Open Home, History, Settings. Fix anything that is unreadable: the `.quaternary` boxes in History, the stat numbers, the sidebar status row. The bar must look the same in both modes.

- [ ] **Step 2: Three recording paths**

Hotkey, bar click, Home button. For each, the bar goes Listening → Finishing → Pasted (or Copied). Home's "Words today" grows after each.

- [ ] **Step 3: Screenshots**

Use `screencapture -l <windowID>` or `screencapture -i` to save: `home-light.png`, `home-dark.png`, `history.png`, `settings.png`, `bar-idle.png`, `bar-listening.png`, `bar-copied.png`, `setup-welcome.png` under `docs/design/screens/`.

- [ ] **Step 4: Tests and build**

```bash
cd Packages/ChirpCore && swift test 2>&1 | tail -3
```
Expected: all pass. Then the xcodebuild command: `BUILD SUCCEEDED`, no warnings from files under `App/`.

- [ ] **Step 5: Commit**

```bash
git add -A docs && git commit -m "Add UI screenshots and mark the design as built"
```

---

## Self-review notes

- Spec coverage: § 3 (Task 4), § 4 (Task 5), § 5.1 (Task 6), § 5.2 and § 5.3 (Task 7), § 5.4 (Task 4), § 6 (Task 3), § 7 (Task 8), § 8 (Task 1), § 9 code map (all), § 10 checks (Tasks 3, 5, 9), § 11 (Task 9).
- The `.floatingButton` case name in `RecordingSource` is kept; it now means "the bar". Renaming it is not needed.
- `windowText` stays on the controller and holds the last Home dictation; Home reads `recent.first` from history instead, so `windowText` can be removed if nothing else uses it after Task 5. Remove it in Task 5 if unused.
