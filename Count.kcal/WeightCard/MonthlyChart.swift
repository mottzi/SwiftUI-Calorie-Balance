import SwiftUI
import Charts

struct MonthlyChart: View {

    @EnvironmentObject private var AppSettings: Settings

    @Environment(WeightHistory.self) private var weightHistory

    var body: some View {
        if let dateRange = weightHistory.chartDateRange(for: .monthly) {
            Chart {
                RuleMark(y: .value("Value", weightHistory.average(for: .monthly)))
                    .foregroundStyle(trendColor.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                
                RectangleMark(
                    xStart: .value("Date", weightHistory.dailyAverages.last!.date.lastMonday),
                    xEnd: .value("Date", weightHistory.dailyAverages.last!.date.nextSunday.tomorrow)
                )
                .foregroundStyle(Color("SecondaryTextColor").opacity(0.1))
                
                let gradient = LinearGradient(
                    stops: [.init(color: trendColor, location: 0.5), .init(color: Color.clear, location: 1.5)],
                    startPoint: .trailing,
                    endPoint: .leading
                )
                
                let validData = weightHistory.validData(.monthly)

                ForEach(Array(validData.enumerated()), id: \.element.id) { (index, item) in
                    LineMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(gradient)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 8))

                    PointMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(Color(index == validData.count - 1 ? "SecondaryTextColor1" : "SecondaryTextColor"))
                    .symbolSize(index == validData.count - 1 ? 113 : 28)

                    PointMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(AppSettings.CardBackground)
                    .symbolSize(index == validData.count - 1 ? 28 : 7)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .brightness(level: .primary)
            .saturation(Settings.baseSaturation)
            .chartYScale(domain: weightHistory.getYRange(.monthly))
            .chartYAxis { AxisMarks(position: .trailing, values: weightHistory.createYRangeArray(.monthly)) }
            .chartXScale(domain: dateRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { date in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day(.twoDigits) , centered: false)
                }
            }

        }
    }
    
}

extension MonthlyChart {

    /// Uses the period trend to select the existing chart color.
    private var trendColor: Color {
        switch weightHistory.trend(for: .monthly) {
            case .orderedAscending: AppSettings.burnedColor
            case .orderedDescending: AppSettings.consumedColor
            default: Color(white: 0.22)
        }
    }

}
