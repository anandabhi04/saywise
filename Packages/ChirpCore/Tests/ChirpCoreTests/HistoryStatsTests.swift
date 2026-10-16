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
