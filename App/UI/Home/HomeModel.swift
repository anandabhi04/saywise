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
