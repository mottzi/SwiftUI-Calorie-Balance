import SwiftUI
import SQLiteData

/// Retrospective calorie choices without changing the daily card's layout.
struct DayChoiceButton: View {

    @Environment(HealthInterface.self) private var healthDay
    @State private var saveFailed = false

    @FetchAll private var records: [StoredDayChoice]

    var body: some View {
        if healthDay.id < Calendar.current.startOfDay(for: Date.now) {
            let choice = AppDatabase.choices(records, sampleData: healthDay.sample.isSampleData)[DayKey.make(healthDay.id)]
                ?? .automatic
            Menu {
                if choice == .excluded {
                    Button("Use recorded data", systemImage: "arrow.uturn.backward") {
                        saveChoice(.automatic)
                    }
                } else {
                    Button("Exclude this day", systemImage: "minus.circle", role: .destructive) {
                        saveChoice(.excluded)
                    }
                }
            } label: {
                Label("Day calculation options", systemImage: symbol(for: choice))
                    .labelStyle(.iconOnly)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color("SecondaryTextColor"))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .menuStyle(.borderlessButton)
            .disabled(healthDay.sample.lastDataSync == nil || $records.isLoading || $records.loadError != nil)
            .accessibilityValue(Text(choice.title))
            .alert("Could not save this choice", isPresented: $saveFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your previous choice is unchanged. Please try again.")
            }
        }
    }

}

extension DayChoiceButton {

    private func saveChoice(_ choice: DayChoice) {
        do {
            try AppDatabase.setChoice(choice, for: healthDay.id, sampleData: healthDay.sample.isSampleData)
        } catch {
            saveFailed = true
        }
    }

    private func symbol(for choice: DayChoice) -> String {
        switch choice {
            case .automatic: "ellipsis"
            case .excluded: "minus.circle"
            case .fasting: healthDay.sample.consumed > 0 ? "exclamationmark.circle" : "moon"
        }
    }

}

extension DayChoice {

    var title: LocalizedStringResource {
        switch self {
            case .automatic: "Automatic"
            case .excluded: "Excluded"
            case .fasting: "Fasting confirmed"
        }
    }

}

extension DayEligibility {

    var title: LocalizedStringResource {
        switch self {
            case .included: "Included"
            case .fasting: "Fasting confirmed"
            case .excluded: "Excluded by you"
            case .missingFood: "No food recorded"
            case .missingEnergy: "Burned energy unavailable"
            case .fastingConflict: "Fasting conflicts with food"
        }
    }

}
