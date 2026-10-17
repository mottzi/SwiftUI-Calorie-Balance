import SwiftUI
import Charts

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

extension WeightSection {

    private func latestDescription(_ weight: Double) -> Text {
        if let date = history.latestWeightDate {
            return Text(
                """
                \(weight, format: .number.precision(.fractionLength(1))) \(settings.weightUnit.rawValue), \
                \(date, format: .dateTime.month().day().year())
                """
            )
        }
        return Text("\(weight, format: .number.precision(.fractionLength(1))) \(settings.weightUnit.rawValue)")
    }

}

private struct WeightSection: View {

    @Environment(WeightHistory.self) private var history

    @EnvironmentObject private var settings: Settings

    let period: WeightPage

    @ScaledMetric(relativeTo: .body) private var chartHeight = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Label {
                    Text(period == .weekly ? "Weekly" : "Monthly")
                } icon: {
                    Image(systemName: "circle.slash")
                        .rotationEffect(.degrees(-90))
                }
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if history.dataLoaded, !history.validData(period).isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(history.average(for: period), format: .number.precision(.fractionLength(1)))
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                        Text(settings.weightUnit.rawValue)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scenePadding(.horizontal)
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
                WeightChart(period: period, dateRange: dateRange)
                    .frame(height: chartHeight)
                    .padding(.horizontal, 4)
            } else {
                Text("No weight data")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .scenePadding(.horizontal)
            }

            if period == .weekly, let weight = history.latestWeight {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(weight, format: .number.precision(.fractionLength(1)))
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                    Text(settings.weightUnit.rawValue)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    if let date = history.latestWeightDate {
                        Text(date.relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .scenePadding(.horizontal)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Last Sample"))
                .accessibilityValue(latestDescription(weight))
            }

            if history.hasLimitedHistory(for: period) {
                Text("Limited history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .scenePadding(.horizontal)
            }
        }
    }

}

private struct WeightChart: View {

    @Environment(WeightHistory.self) private var history

    @EnvironmentObject private var settings: Settings

    let period: WeightPage
    let dateRange: ClosedRange<Date>

    var body: some View {
        Chart {
            let data = history.validData(period)
            let labelledDates = Set(history.labelledData(period).map(\.id))
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
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: period == .weekly ? 1 : 7)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [1, 3]))
                .foregroundStyle(.white.opacity(0.15))

                if period == .weekly {
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                } else {
                    AxisValueLabel(format: .dateTime.day(.twoDigits))
                        .font(.system(.caption, design: .rounded, weight: .medium))
                }
            }
        }
        .chartYAxis {
            AxisMarks(
                preset: .inset,
                position: .trailing,
                values: history.createYRangeArray(period)
            ) {
                AxisValueLabel()
                    .font(.system(.caption, design: .rounded, weight: .medium))
            }

            AxisMarks(values: [history.getYBottomRange(period), history.getYTopRange(period)]) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.15))
            }
        }
        .font(.caption)
        .accessibilityLabel(period == .weekly ? Text("Weekly weight") : Text("Monthly weight"))
    }

}

extension WeightChart {

    private var trendColor: Color {
        switch history.trend(for: period) {
            case .orderedAscending: settings.burnedColor
            case .orderedDescending: settings.consumedColor
            default: .white.opacity(0.8)
        }
    }

}
