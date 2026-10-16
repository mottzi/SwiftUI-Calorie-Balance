import SwiftUI
import Charts

struct MonthlyChart: View {

    @EnvironmentObject private var AppSettings: Settings

    @Environment(WeightHistory.self) private var weightHistory
    @Environment(\.colorScheme) private var colorScheme

    @State private var plotHeight: CGFloat = 0
    @State private var labelHeight: CGFloat = 0

    var body: some View {
        if let dateRange = weightHistory.chartDateRange(for: .monthly) {
            let validData = weightHistory.validData(.monthly)
            let labelledData = weightHistory.labelledData(.monthly)
            let labelledDates = Set(labelledData.map(\.id))

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
                
                ForEach(validData) { item in
                    LineMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(gradient)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 7))

                    if !labelledDates.contains(item.id) {
                        PointMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Value", item.weightAvg!)
                        )
                        .foregroundStyle(Color("SecondaryTextColor").opacity(0.75))
                        .symbolSize(7)
                    }
                }

                ForEach(labelledData) { item in
                    let isLatest = item.id == validData.last?.id

                    PointMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(Color(isLatest ? "SecondaryTextColor1" : "SecondaryTextColor"))
                    .symbolSize(isLatest ? 80 : 28)
                    .annotation(position: labelPosition(for: item.weightAvg!), spacing: 8) {
                        Text(item.weightAvg!, format: .number.precision(.fractionLength(1)))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(isLatest ? "TextColor" : "SecondaryTextColor"))
                            .fixedSize()
                            .onGeometryChange(for: CGFloat.self) { geometry in
                                geometry.size.height
                            } action: { height in
                                labelHeight = height
                            }
                    }

                    PointMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(AppSettings.CardBackground)
                    .symbolSize(isLatest ? 20 : 7)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .brightness(level: .primary)
            .saturation(Settings.baseSaturation)
            .chartYScale(domain: weightHistory.getYRange(.monthly))
            .chartPlotStyle { plot in
                plot.onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { height in
                    plotHeight = height
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: weightHistory.createYRangeArray(.monthly)) {
                    AxisValueLabel()
                        .foregroundStyle(Color("SecondaryTextColor"))
                }

                AxisMarks(values: [weightHistory.getYTopRange(.monthly), weightHistory.getYBottomRange(.monthly)]) {
                    AxisGridLine()
                }
            }
            .chartXScale(domain: dateRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { date in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day(.twoDigits) , centered: false)
                        .foregroundStyle(Color("SecondaryTextColor"))
                }
            }
            .id(colorScheme)

        }
    }
    
}

extension MonthlyChart {

    private func labelPosition(for weight: Double) -> AnnotationPosition {
        guard plotHeight > 0, labelHeight > 0 else { return .top }
        let range = weightHistory.getYRange(.monthly)
        let spaceAbove = CGFloat((Double(range.upperBound) - weight) / Double(range.upperBound - range.lowerBound)) * plotHeight
        let requiredSpace = labelHeight + 8 + 6
        return spaceAbove < requiredSpace && plotHeight - spaceAbove >= requiredSpace ? .bottom : .top
    }

    /// Uses the period trend to select the existing chart color.
    private var trendColor: Color {
        switch weightHistory.trend(for: .monthly) {
            case .orderedAscending: AppSettings.burnedColor
            case .orderedDescending: AppSettings.consumedColor
            default: Color(white: 0.22)
        }
    }

}
