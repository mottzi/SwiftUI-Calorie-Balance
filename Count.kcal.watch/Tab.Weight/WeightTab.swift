import SwiftUI
import Charts

private let weightChartLabelSpacing: CGFloat = 4
private let weightChartValueLabelSize: CGFloat = 11
private let weightChartAxisLabelColor = Color(white: 0.75)

/// Shared weekly and monthly weight, read locally with older phone history when available.
struct WeightTab: View {

    @Environment(WeightHistory.self) private var history

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if history.updatedAt != nil {
                    WeightSection(period: .weekly)
                    WeightSection(period: .monthly)
                } else if history.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    (history.refreshFailed ? Text("Weight unavailable") : Text("No weight data"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .scenePadding(.horizontal)
                }

                if history.refreshFailed {
                    Text("Could not refresh weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .scenePadding(.horizontal)
                }

                if let updatedAt = history.supplementUpdatedAt ?? history.updatedAt, !updatedAt.isToday {
                    Text("Updated: \(updatedAt.relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .scenePadding(.horizontal)
                }
            }
            .padding(.bottom, 12)
        }
        .containerBackground(.black.gradient, for: .tabView)
    }

}

private struct WeightSection: View {

    @Environment(WeightHistory.self) private var history

    @EnvironmentObject private var settings: Settings

    let period: WeightPage

    @ScaledMetric(relativeTo: .body) private var chartHeight = 120

    @State private var plotInsets = EdgeInsets()

    var body: some View {
        VStack(alignment: .leading, spacing: weightChartLabelSpacing) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "circle.slash")
                    .font(.caption2.weight(.medium))
                    .imageScale(.small)
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(.secondary)
                let title = Text(period == .weekly ? "Weekly" : "Monthly")
                    .foregroundStyle(weightChartAxisLabelColor)
                if history.dataLoaded, !history.validData(period).isEmpty {
                    let average = Text(history.average(for: period), format: .number.precision(.fractionLength(1)))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    let unit = Text(settings.weightUnit.rawValue)
                        .font(.system(size: weightChartValueLabelSize, weight: .regular))
                        .foregroundStyle(.white)
                    Text("\(title) \(average)\u{2009}\(unit)")
                        .monospacedDigit()
                } else {
                    title
                }
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(plotInsets)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(period == .weekly ? Text("Weekly average") : Text("Monthly average"))
            .accessibilityValue(
                history.dataLoaded && !history.validData(period).isEmpty
                    ? Text(
                        """
                        \(history.average(for: period), format: .number.precision(.fractionLength(1))) \
                        \(settings.weightUnit.rawValue)
                        """
                    )
                    : Text("No weight data")
            )

            if let dateRange = history.chartDateRange(for: period),
               history.dataLoaded, !history.validData(period).isEmpty {
                WeightChart(period: period, dateRange: dateRange, plotInsets: $plotInsets)
                    .frame(height: chartHeight)
            } else {
                Text("No weight data")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .scenePadding(.horizontal)
            }

            if history.hasLimitedHistory(for: period) {
                Text("Limited history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(plotInsets)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
    }

}

private struct WeightChart: View {

    @Environment(WeightHistory.self) private var history

    @EnvironmentObject private var settings: Settings

    let period: WeightPage
    let dateRange: ClosedRange<Date>

    @Binding var plotInsets: EdgeInsets

    @State private var plotHeight: CGFloat = 0
    @State private var labelHeight: CGFloat = 0

    var body: some View {
        Chart {
            let data = history.validData(period)
            let labelledData = history.labelledData(period)
            let labelledDates = Set(labelledData.map(\.id))
            let valueLabelDates = Set(labelledData.enumerated().compactMap { index, day in
                period == .monthly || (labelledData.count - 1 - index).isMultiple(of: 2) ? day.id : nil
            })
            let gradient = LinearGradient(
                stops: [.init(color: trendColor, location: 0.5), .init(color: .clear, location: 1.5)],
                startPoint: .trailing,
                endPoint: .leading
            )

            RuleMark(y: .value("Average", history.average(for: period)))
                .foregroundStyle(trendColor.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                .accessibilityLabel(Text("Average"))
                .accessibilityValue(
                    Text(
                        """
                        \(history.average(for: period), format: .number.precision(.fractionLength(1))) \
                        \(settings.weightUnit.rawValue)
                        """
                    )
                )

            if let last = history.averages(for: period).last {
                RectangleMark(
                    xStart: .value("Date", period == .weekly ? last.date : last.date.lastMonday),
                    xEnd: .value("Date", dateRange.upperBound)
                )
                .foregroundStyle(.white.opacity(0.05))
                .accessibilityHidden(true)
            }

            ForEach(data) { day in
                if let weight = day.weightAvg {
                    LineMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Weight", weight)
                    )
                    .foregroundStyle(gradient)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: period == .weekly ? 8 : 7))
                    .accessibilityLabel(Text(day.date, format: .dateTime.month().day().year()))
                    .accessibilityValue(
                        Text("\(weight, format: .number.precision(.fractionLength(1))) \(settings.weightUnit.rawValue)")
                    )

                    if labelledDates.contains(day.id) {
                        PointMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Weight", weight)
                        )
                        .foregroundStyle(.white.opacity(day.id == data.last?.id ? 1 : 0.6))
                        .symbolSize(day.id == data.last?.id ? 80 : 28)
                        .annotation(position: labelPosition(for: weight), spacing: 8) {
                            if valueLabelDates.contains(day.id) {
                                Text(weight, format: .number.precision(.fractionLength(1)))
                                    .font(.system(size: weightChartValueLabelSize, weight: .semibold))
                                    .foregroundStyle(.white.opacity(day.id == data.last?.id ? 1 : 0.6))
                                    .fixedSize()
                                    .onGeometryChange(for: CGFloat.self) { geometry in
                                        geometry.size.height
                                    } action: { height in
                                        labelHeight = height
                                    }
                            }
                        }
                        .accessibilityHidden(true)

                        PointMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Weight", weight)
                        )
                        .foregroundStyle(.black)
                        .symbolSize(day.id == data.last?.id ? 20 : 7)
                        .accessibilityHidden(true)
                    } else {
                        PointMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Weight", weight)
                        )
                        .foregroundStyle(.white.opacity(0.45))
                        .symbolSize(7)
                        .accessibilityHidden(true)
                    }
                }
            }
        }
        .chartXScale(domain: dateRange)
        .chartYScale(domain: history.getYRange(period))
        .chartPlotStyle { plot in
            plot
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { height in
                    plotHeight = height
                }
                .overlay {
                    Rectangle()
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                        .allowsHitTesting(false)
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: period == .weekly ? 1 : 7)) { value in
                if let date = value.as(Date.self), date > dateRange.lowerBound, date < dateRange.upperBound {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(.white.opacity(0.3))
                }

                if period == .weekly {
                    AxisValueLabel(
                        format: .dateTime.weekday(.narrow),
                        centered: true,
                        verticalSpacing: weightChartLabelSpacing
                    )
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(weightChartAxisLabelColor)
                } else {
                    AxisValueLabel(
                        format: .dateTime.day(.twoDigits),
                        verticalSpacing: weightChartLabelSpacing
                    )
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(weightChartAxisLabelColor)
                }
            }
        }
        .chartYAxis(.hidden)
        .chartOverlay { proxy in
            Color.clear
                .onGeometryChange(for: EdgeInsets.self) { geometry in
                    guard let anchor = proxy.plotFrame else { return EdgeInsets() }
                    let frame = geometry[anchor]
                    return EdgeInsets(
                        top: 0,
                        leading: frame.minX,
                        bottom: 0,
                        trailing: geometry.size.width - frame.maxX
                    )
                } action: { insets in
                    plotInsets = insets
                }
                .allowsHitTesting(false)
        }
        .font(.caption)
        .accessibilityLabel(period == .weekly ? Text("Weekly weight") : Text("Monthly weight"))
    }

}

extension WeightChart {

    /// Matches the phone: prefer above, moving below when only that side has room.
    private func labelPosition(for weight: Double) -> AnnotationPosition {
        guard plotHeight > 0, labelHeight > 0 else { return .top }
        let range = history.getYRange(period)
        let spaceAbove = CGFloat((Double(range.upperBound) - weight) / Double(range.upperBound - range.lowerBound)) * plotHeight
        let requiredSpace = labelHeight + 8 + 6
        return spaceAbove < requiredSpace && plotHeight - spaceAbove >= requiredSpace ? .bottom : .top
    }

    private var trendColor: Color {
        switch history.trend(for: period) {
            case .orderedAscending: settings.burnedColor
            case .orderedDescending: settings.consumedColor
            default: .white.opacity(0.8)
        }
    }

}
