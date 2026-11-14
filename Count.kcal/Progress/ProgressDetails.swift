import SwiftUI
import SQLiteData

/// Coverage and reversible exclusions for the selected completed period.
struct ProgressDetails: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var settings: Settings
    @ScaledMetric(relativeTo: .body) private var summaryHeight: CGFloat = 380
    @ScaledMetric(relativeTo: .body) private var omittedSectionHeight: CGFloat = 66
    @ScaledMetric(relativeTo: .body) private var omittedRowHeight: CGFloat = 56
    @State private var saveFailed = false
    @State private var showsPicker = false
    @State private var summaryWhilePicking: ProgressSummary?
    @FetchAll private var records: [StoredDayChoice]

    let history: ProgressHistory
    let period: ProgressPeriod

    var body: some View {
        let liveSummary = history.summary(
            for: period,
            choices: AppDatabase.choices(records, sampleData: HealthDataMode.isSampleDataEnabled)
        )
        // Keep the presenting sheet at the same height while the picker is open.
        let summary = summaryWhilePicking ?? liveSummary
        let omittedDays = summary.days.reversed().filter { !$0.eligibility.isIncluded }
        let editableDays = liveSummary.days.reversed().filter {
            $0.eligibility.isIncluded || $0.eligibility == .excluded
        }
        ProgressSheetContent(title: "Balance average", detent: detent(omittedCount: omittedDays.count)) {
            if $records.loadError != nil {
                Text("Saved choices unavailable").font(.headline)
                Text("Reopen the app to try again. Your choices are unchanged.")
                    .foregroundStyle(.secondary)
            } else if history.energyFailed {
                Text("Calorie data unavailable").font(.headline)
                Text("Pull down on the dashboard to try again.")
                    .foregroundStyle(.secondary)
            } else if history.isLoading || $records.isLoading {
                ProgressView("Loading days…")
                    .frame(maxWidth: .infinity)
            } else {
                Text("Your average daily calorie deficit or surplus, based on the days included.")
                    .font(.subheadline)

                balanceCard(summary)

                if !omittedDays.isEmpty {
                    ProgressExcludedDays(days: omittedDays) { date in
                        do {
                            try saveChoice(.automatic, for: date)
                        } catch {
                            saveFailed = true
                        }
                    }
                }

                if !editableDays.isEmpty {
                    Button {
                        summaryWhilePicking = liveSummary
                        showsPicker = true
                    } label: {
                        Label("Exclude days", systemImage: "calendar.badge.minus")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                }
            }
        }
        .sheet(isPresented: $showsPicker, onDismiss: { summaryWhilePicking = nil }) {
            ProgressDayPicker(
                days: editableDays,
                dateRange: dateRange,
                canEdit: !history.isLoading && !$records.isLoading && $records.loadError == nil && !history.energyFailed,
                saveChoice: saveChoice
            )
        }
        .alert("Could not save", isPresented: $saveFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your choice is unchanged. Try again.")
        }
    }

    private func detent(omittedCount: Int) -> PresentationDetent {
        if dynamicType.isAccessibilitySize || omittedCount > 6 { return .large }
        guard omittedCount > 0 else { return .height(summaryHeight) }
        return .height(summaryHeight + omittedSectionHeight + omittedRowHeight * CGFloat(omittedCount))
    }

    private func balanceCard(_ summary: ProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let average = summary.averageDeficit {
                let balance = average.rounded()
                let direction: LocalizedStringResource = balance > 0 ? "Daily deficit" : balance < 0 ? "Daily surplus" : "Daily balance"
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(abs(balance), format: .number.precision(.fractionLength(0))) \(Text(settings.energyUnit.rawValue).font(.title3).foregroundStyle(.secondary))")
                        .font(.largeTitle.weight(.semibold))
                        .monospacedDigit()
                    Text(direction)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("At least 2 days needed for an average.")
                    .font(.subheadline)
            }

            Divider()

            VStack(alignment: .leading, spacing: 3) {
                if summary.includedDays == period.rawValue {
                    Text("All \(period.rawValue) days included")
                } else {
                    Text("\(summary.includedDays) of \(period.rawValue) days included")
                }
                Text(dateRange).foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }

    private func saveChoice(_ choice: DayChoice, for date: Date) throws {
        try AppDatabase.setChoice(choice, for: date, sampleData: HealthDataMode.isSampleDataEnabled)
    }

    private var dateRange: String {
        let interval = period.interval(endingBefore: history.today)
        let last = Calendar.current.date(byAdding: .day, value: -1, to: interval.end)!
        return interval.start.formatted(.dateTime.day().month(.abbreviated))
            + " – " + last.formatted(.dateTime.day().month(.abbreviated))
    }

}
