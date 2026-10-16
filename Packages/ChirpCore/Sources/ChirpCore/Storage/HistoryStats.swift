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

        var appWords: [String: AppWords] = [:]

        for entry in entries {
            let words = wordCount(entry.finalText)
            let day = calendar.startOfDay(for: entry.createdAt)
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

        let activeDays = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
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
