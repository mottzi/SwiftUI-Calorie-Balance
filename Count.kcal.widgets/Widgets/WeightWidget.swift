import AppIntents
import SwiftUI
import WidgetKit

struct WeightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeightProgressWidget", provider: WeightWidgetProvider()) { entry in
            WeightWidgetContent(entry: entry)
                .containerBackground(Color("BackGroundColorBlack"), for: .widget)
                .environmentObject(Settings.shared)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Weight Progress")
        .description("Your weekly or monthly weight graph.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WeightWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WeightHistorySnapshot?
    let page: WeightPage
    let failed: Bool
}

struct WeightWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeightWidgetEntry {
        WeightWidgetEntry(date: .now, snapshot: sampleSnapshot(), page: .weekly, failed: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeightWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeightWidgetEntry>) -> Void) {
        Task { @MainActor in
            let date = Date.now
            let history = WeightHistory()
            await history.fetchData()
            let page = WeightWidgetMode.isMonthly ? WeightPage.monthly : .weekly
            let entry = WeightWidgetEntry(
                date: date,
                snapshot: history.snapshot,
                page: page,
                failed: history.refreshFailed
            )
            let midnight = Calendar.current.nextDate(
                after: date,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            )!
            completion(Timeline(
                entries: [entry],
                policy: .after(min(date.addingTimeInterval(15 * 60), midnight))
            ))
        }
    }

    private func sampleSnapshot() -> WeightHistorySnapshot {
        let today = Calendar.current.startOfDay(for: .now)
        let start = today.subtractDays(30).lastMonday
        let count = Calendar.current.dateComponents([.day], from: start, to: today).day! + 1
        let values = (0..<count).map { index in
            WeightChartData(
                date: start.addDays(index),
                weightAvg: WeightChartData.roundedWeight(82.4 - Double(index) * 2.8 / Double(count - 1))
            )
        }
        return WeightHistorySnapshot(
            dailyAverages: values,
            latestWeight: values.last?.weightAvg,
            latestWeightDate: today,
            unit: UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")?.string(forKey: "weightUnit") ?? "kg",
            updatedAt: .now
        )
    }
}

private enum WeightWidgetMode {
    static let key = "weightWidgetMonthlyMode"
    static let defaults = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")!

    static var isMonthly: Bool { defaults.bool(forKey: key) }

    static func toggle() {
        defaults.set(!isMonthly, forKey: key)
    }

    static func select(_ period: WeightWidgetPeriod) {
        defaults.set(period == .monthly, forKey: key)
    }
}

enum WeightWidgetPeriod: String, AppEnum {
    case weekly = "weekly"
    case monthly = "monthly"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Weight graph period"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .weekly: "Weekly",
        .monthly: "Monthly"
    ]
}

struct SetWeightWidgetPeriodIntent: AppIntent {
    static let title: LocalizedStringResource = "Select weight graph period"

    @Parameter(title: "Period") var period: WeightWidgetPeriod

    init() {}

    init(_ period: WeightWidgetPeriod) {
        self.period = period
    }

    func perform() async throws -> some IntentResult {
        WeightWidgetMode.select(period)
        return .result()
    }
}

struct ToggleWeightWidgetModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Switch weight graph period"
    static let description = IntentDescription("Switch between weekly and monthly weight graphs.")

    func perform() async throws -> some IntentResult {
        WeightWidgetMode.toggle()
        return .result()
    }
}

private struct WeightWidgetContent: View {
    @Environment(\.widgetFamily) private var family

    let entry: WeightWidgetEntry
    let history: WeightHistory

    init(entry: WeightWidgetEntry) {
        self.entry = entry
        let history = WeightHistory()
        if let snapshot = entry.snapshot { history.apply(snapshot) }
        self.history = history
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                WeightWidgetHeader(
                    page: entry.page,
                    average: history.average(for: entry.page),
                    latestWeight: history.latestWeight,
                    latestWeightDate: history.latestWeightDate
                )
                .padding(.leading, family == .systemSmall ? 14 : 18)
                .padding(.trailing, family == .systemSmall ? 8 : 18)

                if history.validData(entry.page).isEmpty {
                    WeightWidgetEmptyState(failed: entry.failed)
                } else {
                    chart
                        .padding(.top, family == .systemSmall ? 6 : 10)
                        .padding(.leading, family == .systemSmall ? 8 : 15)
                        .padding(.trailing, family == .systemSmall ? 7 : 13)
                        .padding(.bottom, 6)
                }
            }
            .padding(.top, family == .systemSmall ? 9 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        }
        .environment(history)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    @ViewBuilder
    private var chart: some View {
        if entry.page == .weekly {
            WeeklyChart(showsAlternateLabels: family == .systemSmall)
        } else {
            MonthlyChart(showsAlternateLabels: family == .systemSmall)
        }
    }
}

private struct WeightWidgetHeader: View {
    @Environment(\.widgetFamily) private var family
    @EnvironmentObject private var settings: Settings

    let page: WeightPage
    let average: Double
    let latestWeight: Double?
    let latestWeightDate: Date?

    private var unit: String { settings.weightUnit == .lbs ? "lbs" : "kg" }
    private var latestWeightLabel: String {
        latestWeightDate?.relative ?? String(localized: "Last Sample")
    }

    var body: some View {
        if family == .systemMedium {
            HStack(spacing: 0) {
                HStack(alignment: .center, spacing: 20) {
                    VStack(alignment: .leading, spacing: 0) {
                        WeightWidgetValue(value: average == 0 ? nil : average, unit: unit, size: .primary)
                        HStack(spacing: 4) {
                            Text(page == .weekly ? "Weekly" : "Monthly")
                            Text(verbatim: "⌀")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(height: 13)
                                .accessibilityHidden(true)
                        }
                        .font(.caption2)
                        .foregroundStyle(Color("SecondaryTextColor"))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(page == .weekly ? "Weekly average" : "Monthly average")
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        WeightWidgetValue(value: latestWeight, unit: unit, size: .primary)
                        Text(latestWeightLabel)
                            .font(.caption2)
                            .foregroundStyle(Color("SecondaryTextColor"))
                    }
                }

                Spacer(minLength: 12)

                WeightWidgetPeriodPicker(page: page)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        } else {
            HStack(spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        WeightWidgetValue(value: average == 0 ? nil : average, unit: unit, size: .small)
                        HStack(spacing: 2) {
                            Text(page == .weekly ? "Weekly" : "Monthly")
                            Text(verbatim: "⌀")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(height: 12)
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(page == .weekly ? "Weekly average" : "Monthly average")
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        WeightWidgetValue(value: latestWeight, unit: unit, size: .small)
                        Text(latestWeightLabel)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(Color("SecondaryTextColor"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)

                Spacer(minLength: 2)

                WeightWidgetModeButton(page: page)
            }
        }
    }
}

private struct WeightWidgetValue: View {
    enum Size {
        case primary, small

        var fontSize: CGFloat {
            switch self {
            case .primary: 23
            case .small: 16
            }
        }
    }

    let value: Double?
    let unit: String
    let size: Size

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: size == .primary ? 3 : 2) {
            Group {
                if let value {
                    Text(value, format: .number.precision(.fractionLength(1)))
                } else {
                    Text("-/-")
                }
            }
            .font(.system(size: size.fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(Color("TextColor"))

            Text(verbatim: unit)
                .font(size == .small ? .system(size: 9) : .caption2)
                .foregroundStyle(Color("SecondaryTextColor"))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private struct WeightWidgetModeButton: View {
    let page: WeightPage

    var body: some View {
        Button(intent: ToggleWeightWidgetModeIntent()) {
            Text(page == .weekly ? "7D" : "30D")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color("TextColor"))
                .frame(width: 44, height: 44)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("TextColor").opacity(0.08))
                            .frame(width: 32, height: 32)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color("TextColor").opacity(0.2))
                            .frame(width: 26, height: 26)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(page == .weekly ? "Show monthly weight graph" : "Show weekly weight graph")
    }
}

private struct WeightWidgetPeriodPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let page: WeightPage
    private let segmentWidth: CGFloat = 44

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("TextColor").opacity(0.08))
                .frame(height: 32)

            RoundedRectangle(cornerRadius: 6)
                .fill(Color("TextColor").opacity(0.2))
                .frame(width: segmentWidth, height: 26)
                .offset(x: page == .weekly ? 3 : 3 + segmentWidth)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: page)

            HStack(spacing: 0) {
                ForEach(WeightWidgetPeriod.allCases, id: \.self) { period in
                    let selected = (page == .monthly) == (period == .monthly)
                    Button(intent: SetWeightWidgetPeriodIntent(period)) {
                        Text(period == .weekly ? "7D" : "30D")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(selected ? "TextColor" : "SecondaryTextColor"))
                            .frame(width: segmentWidth, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(period == .weekly ? "Weekly weight graph" : "Monthly weight graph")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 3)
        }
        .frame(width: segmentWidth * 2 + 6, height: 44)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Weight graph period")
    }
}

private struct WeightWidgetEmptyState: View {
    let failed: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "scalemass")
                .font(.title3)
            Text(failed ? "Weight data unavailable" : "No weight measurements")
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color("SecondaryTextColor"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

