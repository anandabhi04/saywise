import SwiftUI

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
