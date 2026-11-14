import SwiftUI
import SQLiteData

/// Two period summaries and an explanation of the days used in the average.
struct ProgressMetrics: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var settings: Settings

    @State private var showDetails = false

    @FetchAll private var records: [StoredDayChoice]

    let history: ProgressHistory
    let period: ProgressPeriod

    var body: some View {
        let summary = history.summary(
            for: period,
            choices: AppDatabase.choices(records, sampleData: HealthDataMode.isSampleDataEnabled)
        )
        VStack(spacing: 0) {
            metrics(summary)
                .padding(.vertical, 16)
            Divider()
            Button { showDetails = true } label: {
                HStack(spacing: 8) {
                    Text(history.isLoading || $records.isLoading ? "Loading completed days…" : coverage(summary))
                        .font(.footnote)
                        .foregroundStyle(Color("SecondaryTextColor"))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(history.isLoading || $records.isLoading)
            .accessibilityHint("Review omitted days and manage exclusions")
        }
        .sheet(isPresented: $showDetails) {
            ProgressDetails(history: history, period: period)
        }
    }

}

extension ProgressMetrics {

    private func metrics(_ summary: ProgressSummary) -> some View {
        let layout = dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        return layout {
            metric(
                value: weightValue(summary),
                title: "Weight change",
                detail: period == .week ? "vs previous 7 days" : "vs previous 30 days"
            )
            metric(
                value: energyValue(summary),
                title: "Average deficit / day",
                detail: "Goal \(settings.balanceGoal) \(settings.energyUnit.rawValue)"
            )
        }
    }

    private func metric(value: String, title: LocalizedStringResource, detail: LocalizedStringResource) -> some View {
        VStack(alignment: dynamicType.isAccessibilitySize ? .leading : .center, spacing: 4) {
            Text(verbatim: value)
                .accessibilityLabel(value == "—" ? String(localized: "Not enough data") : value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color("TextColor"))
                .fixedSize(horizontal: false, vertical: true)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color("SecondaryTextColor"))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(dynamicType.isAccessibilitySize ? .leading : .center)
        .frame(maxWidth: .infinity, alignment: dynamicType.isAccessibilitySize ? .leading : .center)
        .accessibilityElement(children: .combine)
    }

    private func weightValue(_ summary: ProgressSummary) -> String {
        guard !history.isLoading, let change = summary.weightChange else { return "—" }
        let rounded = abs(change) < 0.05 ? 0 : (change * 10).rounded() / 10
        return rounded.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false)))
            + " " + settings.weightUnit.rawValue
    }

    private func energyValue(_ summary: ProgressSummary) -> String {
        guard !history.isLoading, !$records.isLoading, $records.loadError == nil,
              let deficit = summary.averageDeficit else { return "—" }
        return deficit.rounded().formatted(.number.precision(.fractionLength(0))) + " " + settings.energyUnit.rawValue
    }

    private func coverage(_ summary: ProgressSummary) -> LocalizedStringResource {
        if $records.loadError != nil { return "Saved choices unavailable" }
        if history.energyFailed { return "Calorie data unavailable" }
        return "\(summary.includedDays) of \(period.rawValue) days included"
    }

}
