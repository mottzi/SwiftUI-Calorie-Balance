import SwiftUI

/// Switches today's calorie graphs in place while retaining the selected mode.
struct CaloriesMidnightCard: View {

    nonisolated static let rimDepth = RecessedCardStyle.rimDepth

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(HealthInterface.self) private var day

    @EnvironmentObject private var settings: Settings

    @Binding var todayPageMode: TodayPageMode
    @State private var feedback = RecessedCardFeedback()

    var body: some View {
        Button(action: toggleMode) {
            CaloriesCard(mode: mode, animateNumericValues: true)
                .animation(reduceMotion ? nil : .snappy, value: todayPageMode.selection)
                .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(RecessedCardStyle(
            background: settings.CardBackground,
            feedback: feedback,
            pulse: todayPageMode.toolbarActivations
        ))
        .accessibilityLabel("Calories")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(mode == .now ? "Show the midnight estimate" : "Show the current balance")
        .accessibilityInputLabels(["Calories", "Calorie balance"])
    }

}

extension CaloriesMidnightCard {

    private func toggleMode() {
        feedback.activate()
        todayPageMode.toggle(from: .card)
    }

    private var mode: GraphMode { todayPageMode.selection == .first ? .now : .midnight }

    private var accessibilityValue: Text {
        let energy = mode == .now ? day.sample.now : day.sample.midnight
        let unit = settings.energyUnit == .kJ ? "kJ" : "kcal"
        let modeTitle: LocalizedStringKey = mode == .now ? "Now" : "Midnight"
        let balanceTitle: LocalizedStringKey = energy.isEmpty || energy.balance == 0
            ? "Balance"
            : energy.balance > 0 ? "Deficit" : "Surplus"
        return Text(
            "\(Text(modeTitle)). \(Text(balanceTitle)) \(abs(energy.balance)) \(unit). Burned \(energy.burned) \(unit). Eaten \(energy.consumed) \(unit)."
        )
    }

}

#Preview { PreviewPager }
