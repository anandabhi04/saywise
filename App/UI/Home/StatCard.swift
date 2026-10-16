import SwiftUI

struct StatCard: View {
    var label: String
    var value: String
    var detail: String
    var animate: Bool
    @State private var shown: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
            Text(displayValue)
                .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .onAppear {
            guard animate, let target = Int(value.filter(\.isNumber)) else { shown = -1; return }
            withAnimation(.easeOut(duration: 0.6)) { shown = Double(target) }
        }
    }

    private var displayValue: String {
        if shown < 0 { return value }
        guard let target = Int(value.filter(\.isNumber)), target > 0 else { return value }
        return Int(shown).formatted()
    }
}
