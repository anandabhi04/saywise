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
