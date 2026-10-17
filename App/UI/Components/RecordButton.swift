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
            ProgressView().controlSize(.small).tint(Color(nsColor: .windowBackgroundColor))
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
