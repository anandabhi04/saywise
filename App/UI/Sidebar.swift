import SwiftUI

struct Sidebar: View {
    let controller: AppController
    @Binding var page: Page

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding<Page?>(
                get: { page },
                set: { if let selection = $0 { page = selection } }
            )) {
                ForEach(Page.allCases) { page in
                    Label(page.title, systemImage: page.symbol).tag(page)
                }
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
