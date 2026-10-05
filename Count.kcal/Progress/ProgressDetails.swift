import SwiftUI
import SQLiteData

/// Coverage and reversible day choices for the selected completed period.
struct ProgressDetails: View {

    @Environment(\.dismiss) private var dismiss

    @State private var saveFailed = false

    @FetchAll private var records: [StoredDayChoice]

    let history: ProgressHistory
    let period: ProgressPeriod

    var body: some View {
        let summary = history.summary(
            for: period,
            choices: AppDatabase.choices(records, sampleData: HealthDataMode.isSampleDataEnabled)
        )
        NavigationStack {
            List {
                if $records.loadError != nil {
                    Section {
                        Text("Saved choices unavailable")
                        Text("Close this sheet and reopen the app to try again. Your saved choices have not been changed.")
                            .foregroundStyle(.secondary)
                    }
                } else if history.energyFailed {
                    Section {
                        Label("Calorie data unavailable", systemImage: "exclamationmark.circle")
                        Text("Close this sheet and pull down on the dashboard to try again.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(summary.days.reversed(), id: \.day.id) { item in
                            Menu {
                                if item.eligibility == .excluded {
                                    Button("Use recorded data", systemImage: "arrow.uturn.backward") {
                                        saveChoice(.automatic, for: item.day.date)
                                    }
                                } else {
                                    Button("Exclude this day", systemImage: "minus.circle", role: .destructive) {
                                        saveChoice(.excluded, for: item.day.date)
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: symbol(for: item.eligibility))
                                        .foregroundStyle(color(for: item.eligibility))
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(
                                            item.day.date,
                                            format: .dateTime.weekday(.abbreviated).day().month(.abbreviated)
                                        )
                                            .foregroundStyle(.primary)
                                        Text(item.eligibility.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "ellipsis")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                        .accessibilityHidden(true)
                                }
                                .frame(minHeight: 44)
                                .contentShape(.rect)
                            }
                            .menuStyle(.borderlessButton)
                            .disabled($records.isLoading || $records.loadError != nil)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateRange)
                            Text("\(summary.includedDays) of \(period.rawValue) completed days included")
                        }
                    } footer: {
                        Text("""
                        At least two included days are needed for an average. Recorded data can \
                        still be incomplete. Exclude any day you know is unreliable.
                        """)
                    }
                }
                Section {
                    Text("""
                    Average deficit is energy burned minus food intake, averaged over included days. \
                    A negative value means a surplus. Today is still in progress and stays out.
                    """)
                    Text("""
                    Weight change compares average recorded weight with the previous period. Missing \
                    weigh-ins are skipped. At least two recorded days are needed in each period.
                    """)
                } header: {
                    Text("Calculation")
                }
                .font(.subheadline)

                if history.weightFailed {
                    Section { Text("Weight data unavailable") }
                }
            }
            .navigationTitle("Days included")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .alert("Could not save this choice", isPresented: $saveFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your previous choice is unchanged. Please try again.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

}

extension ProgressDetails {

    private func saveChoice(_ choice: DayChoice, for date: Date) {
        do {
            try AppDatabase.setChoice(choice, for: date, sampleData: HealthDataMode.isSampleDataEnabled)
        } catch {
            saveFailed = true
        }
    }

    private func symbol(for eligibility: DayEligibility) -> String {
        if eligibility == .fastingConflict { return "exclamationmark.circle" }
        return eligibility.isIncluded ? "checkmark.circle" : "minus.circle"
    }

    private func color(for eligibility: DayEligibility) -> Color {
        if eligibility == .fastingConflict { return .orange }
        return eligibility.isIncluded ? .accentColor : .secondary
    }

    private var dateRange: String {
        let interval = period.interval(endingBefore: history.today)
        let last = Calendar.current.date(byAdding: .day, value: -1, to: interval.end)!
        return interval.start.formatted(.dateTime.day().month(.abbreviated))
            + " – " + last.formatted(.dateTime.day().month(.abbreviated))
    }

}
