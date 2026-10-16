import SwiftUI
import Charts

struct WeeklyChart: View {

    @EnvironmentObject private var AppSettings: Settings

    @Environment(WeightHistory.self) private var weightHistory
    @Environment(\.colorScheme) private var colorScheme

    @State private var plotSize: CGSize = .zero
    @State private var labelHeight: CGFloat = 0
    @State private var labelWidth: CGFloat = 0

    var body: some View {
        if let dateRange = weightHistory.chartDateRange(for: .weekly) {
            Chart {
                // average line horizontal
                RuleMark(y: .value("Value", weightHistory.average(for: .weekly)))
                    .foregroundStyle(trendColor.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                
                // today highlight background
                RectangleMark(
                    xStart: .value("Date", weightHistory.weeklyAverages.last!.date.tomorrow),
                    xEnd: .value("Date", weightHistory.weeklyAverages.last!.date)
                )
                    .foregroundStyle(Color("SecondaryTextColor").opacity(0.1))
                
                let gradient = LinearGradient(
                    stops: [.init(color: trendColor, location: 0.5), .init(color: Color.clear, location: 1.5)],
                    startPoint: .trailing,
                    endPoint: .leading
                )
                
                let validData = weightHistory.validData(.weekly)

                ForEach(Array(validData.enumerated()), id: \.element.id) { (index, item) in
                    let spacing: CGFloat = plotSize.width > 0 && labelWidth + 4 > plotSize.width / 7 && index.isMultiple(of: 2) ? 24 : 8
                    LineMark(
                        x: .value("Date", item.date, unit: .weekday),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(gradient)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 8))

                    PointMark(
                        x: .value("Date", item.date, unit: .weekday),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(Color(index == validData.count - 1 ? "SecondaryTextColor1" : "SecondaryTextColor"))
                    .symbolSize(index == validData.count - 1 ? 113 : 50)
                    .annotation(position: labelPosition(for: item.weightAvg!, spacing: spacing), spacing: spacing) {
                        Text(verbatim: String(format: "%.1f", item.weightAvg!))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(index == validData.count - 1 ? "TextColor" : "SecondaryTextColor"))
                            .fixedSize()
                            .onGeometryChange(for: CGSize.self) { geometry in
                                geometry.size
                            } action: { size in
                                labelHeight = size.height
                                labelWidth = max(labelWidth, size.width)
                            }
                    }

                    PointMark(
                        x: .value("Date", item.date, unit: .weekday),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(AppSettings.CardBackground)
                    .symbolSize(index == validData.count - 1 ? 28 : 13)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .brightness(level: .primary)
            .saturation(Settings.baseSaturation)
            .chartYScale(domain: weightHistory.getYRange(.weekly))
            .chartPlotStyle { plot in
                plot.onGeometryChange(for: CGSize.self) { geometry in
                    geometry.size
                } action: { size in
                    plotSize = size
                }
            }
            .chartYAxis {
                AxisMarks(values: weightHistory.createYRangeArray(.weekly)) {
                    AxisValueLabel()
                        .foregroundStyle(Color("SecondaryTextColor"))
                }
                
                AxisMarks(values: [weightHistory.getYTopRange(.weekly), weightHistory.getYBottomRange(.weekly)]) {
                    AxisGridLine()
                }
                
            }
            .chartXScale(domain: dateRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { day in
                    if day.index != 0 && day.index != day.count - 1 {
                        AxisGridLine()
                    } else {
                        AxisGridLine(stroke: .init(lineWidth: 0.5))
                    }
                    
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .foregroundStyle(Color("SecondaryTextColor"))
                }
            }
            .id(colorScheme)
        }
    }
    
}

extension WeeklyChart {

    private func labelPosition(for weight: Double, spacing: CGFloat) -> AnnotationPosition {
        let plotHeight = plotSize.height
        guard plotHeight > 0, labelHeight > 0 else { return .top }
        let range = weightHistory.getYRange(.weekly)
        let spaceAbove = CGFloat((Double(range.upperBound) - weight) / Double(range.upperBound - range.lowerBound)) * plotHeight
        let requiredSpace = labelHeight + spacing + 6
        return spaceAbove < requiredSpace && plotHeight - spaceAbove >= requiredSpace ? .bottom : .top
    }

    /// Uses the period trend to select the existing chart color.
    private var trendColor: Color {
        switch weightHistory.trend(for: .weekly) {
            case .orderedAscending: AppSettings.burnedColor
            case .orderedDescending: AppSettings.consumedColor
            default: Color(white: 0.22)
        }
    }

}

#Preview { PreviewPager }
