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
