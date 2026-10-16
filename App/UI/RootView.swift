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
                .toolbar(removing: .sidebarToggle)
        } detail: {
            ZStack {
                switch state.page {
                case .home: HomeView(controller: controller, state: state)
                case .history: HistoryView(controller: controller, focus: $state.historyFocus)
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
        .frame(minWidth: 820, minHeight: 560)
    }
}

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
