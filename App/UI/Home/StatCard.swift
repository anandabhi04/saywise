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
        .onChange(of: value, initial: true) { oldValue, newValue in
            guard let target = integerValue else { return }
            if oldValue == newValue && !animate {
                shown = Double(target)
            } else {
                withAnimation(.easeOut(duration: 0.6)) { shown = Double(target) }
            }
        }
    }

    private var integerValue: Int? {
        Int(value.replacingOccurrences(of: Locale.current.groupingSeparator ?? ",", with: ""))
    }

    private var displayValue: String {
        guard integerValue != nil else { return value }
        return Int(shown).formatted()
    }
}
