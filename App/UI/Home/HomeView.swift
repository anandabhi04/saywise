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
        if controller.homeBanner != nil { return .orange }
        return switch controller.status {
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
