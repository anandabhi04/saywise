import Charts
import ChirpCore
import SwiftUI

struct ActivityChart: View {
    var days: [HistoryStats.Day]
    @State private var hovered: HistoryStats.Day?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Last 14 days").font(.headline)
                Spacer()
                if let hovered {
                    Text("\(hovered.date.formatted(.dateTime.weekday(.wide).day().month())) · \(hovered.words) words")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ZStack {
                Chart(days, id: \.date) { day in
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Words", day.words))
                        .foregroundStyle(Color.accentColor.opacity(isToday(day) ? 1 : 0.5))
                        .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .chartYAxis(.hidden)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case let .active(point):
                                    let x = point.x - geo[proxy.plotFrame!].origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        hovered = days.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
                                    }
                                case .ended: hovered = nil
                                }
                            }
                    }
                }
                if days.allSatisfy({ $0.words == 0 }) {
                    Text("Start talking to see your numbers").font(.callout).foregroundStyle(.secondary)
                }
            }
            .frame(height: 140)
        }
        .card()
    }

    private func isToday(_ day: HistoryStats.Day) -> Bool { Calendar.current.isDateInToday(day.date) }
}
