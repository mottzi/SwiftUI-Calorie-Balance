import SwiftUI

/// Now or midnight calorie totals and balance for one day.
struct CaloriesCard: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(HealthInterface.self) private var day

    @EnvironmentObject private var settings: Settings

    let mode: GraphMode
    var animateNumericValues = false

    var body: some View {
        let energy = mode == .now ? day.sample.now : day.sample.midnight
        CalorieCardContent(
            energy: energy,
            energyUnit: settings.energyUnit.rawValue,
            burnedColor: settings.burnedColor,
            consumedColor: settings.consumedColor,
            graphEmptyColor: settings.getGraphEmptyColor(scheme),
            cardBackground: settings.CardBackground,
            visibleGoalReached: settings.hideCalorieStatusIcons || energy.isEmpty ? nil
                : energy.meetsGoal(settings.balanceGoal, isLoss: settings.weightGoal == .lose),
            labelBackground: settings.showCalorieLabelBackgrounds ? settings.calorieLabelBackground.labelBackgroundColor : nil,
            isLoading: !day.hasLoadedSnapshot,
            animateNumericValues: animateNumericValues
        )
    }
}

/// Shared native card presentation for local and received calorie values.
struct CalorieCardContent: View {

    /// Dynamic type size used to choose the card layout.
    @Environment(\.dynamicTypeSize) private var dynamicType

    /// Appearance used for graph spacing and empty color.
    @Environment(\.colorScheme) private var scheme

    /// Energy values displayed by the card.
    let energy: EnergyBalance

    /// Unit label shown with energy values.
    let energyUnit: String

    /// Color used for burned energy.
    let burnedColor: Color

    /// Color used for consumed energy.
    let consumedColor: Color

    /// Color used for empty graph space.
    let graphEmptyColor: Color

    /// Background color for the card.
    let cardBackground: Color

    /// Goal result shown when the sender's policy allows it.
    let visibleGoalReached: Bool?

    var labelBackground: Color? = nil

    /// Whether the health sample is still loading.
    var isLoading = false

    /// Whether graph values animate when they change.
    var animateNumericValues = false

    /// Graph height for each supported dynamic type size.
    let sizeMapping: [DynamicTypeSize: CGFloat] = 
    [
        .xSmall: 44,
        .small: 44,
        .medium: 44,
        .large: 44,
        .xLarge: 46,
        .xxLarge: 48,
        .xxxLarge: 50,
        .accessibility1: 52,
        .accessibility2: 54,
        .accessibility3: 56,
        .accessibility4: 58,
        .accessibility5: 60,
    ]
    
    /// Shows card totals and graph, with full component values at accessibility sizes.
    var body: some View {
        VStack(spacing: dynamicType.isAccessibilitySize ? 8 : 0) {
            if dynamicType.isAccessibilitySize {
                AccessibleCalorieTotals(energy: energy, energyUnit: energyUnit,
                                      visibleGoalReached: visibleGoalReached, isLoading: isLoading)
            } else {
                CaloriesCardTopRow(
                    energy: energy, energyUnit: energyUnit, burnedColor: burnedColor,
                    consumedColor: consumedColor, graphEmptyColor: graphEmptyColor,
                    visibleGoalReached: visibleGoalReached, isLoading: isLoading
                )
                    .padding(.top, 2)
            }

            CalorieBarGraph(
                energy: energy,
                configuration: CalorieBarConfiguration(
                    rowSpacing: scheme == .light ? 1 : 2,
                    showsLabels: !dynamicType.isAccessibilitySize && !isLoading,
                    usesContrastLabelBackground: labelBackground != nil,
                    labelBackgroundColor: labelBackground ?? .clear,
                    animatesNumericValues: animateNumericValues
                ),
                palette: barPalette
            )
                .padding(.bottom, scheme == .light ? 1 : 0)
                .opacity(isLoading ? 0 : 1)
                .overlay {
                    if isLoading {
                        VStack(spacing: scheme == .light ? 1 : 2) {
                            RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                            RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                        }
                        .padding(.bottom, scheme == .light ? 1 : 0)
                        .accessibilityHidden(true)
                    }
                }
                .frame(height: sizeMapping[dynamicType, default: 44])
                .padding(.top, 6)
                .padding(.bottom, 2)
                .padding(.horizontal, 13)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(cardBackground)
        .clipShape(.rect(cornerRadius: 10))
    }

}

extension CalorieCardContent {

    /// Applies the current appearance's empty-space opacity to the graph colors.
    private var barPalette: CalorieGraphPalette {
        var palette = CalorieGraphPalette(burned: burnedColor, consumed: consumedColor, empty: graphEmptyColor)
        palette.empty.opacity = scheme == .light ? 0.4 : 1
        return palette
    }

}

#Preview { PreviewPager }

/// Full calorie totals for accessible text sizes.
private struct AccessibleCalorieTotals: View {

    /// Energy values whose components are shown.
    let energy: EnergyBalance

    /// Unit label shown with each value.
    let energyUnit: String

    /// Goal result allowed by the sender's card policy.
    let visibleGoalReached: Bool?

    /// Whether displayed values are still loading.
    let isLoading: Bool

    /// Lists the full calorie components and any visible goal result.
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AccessibleCalorieValue("Burned", value: energy.burned, energyUnit: energyUnit, isLoading: isLoading)
            AccessibleCalorieValue("Eaten", value: energy.consumed, energyUnit: energyUnit, isLoading: isLoading)
            AccessibleCalorieValue(
                energy.isEmpty || energy.balance == 0 ? "Balance"
                    : energy.balance > 0 ? "Deficit"
                    : "Surplus",
                value: abs(energy.balance),
                energyUnit: energyUnit,
                isLoading: isLoading
            )
            AccessibleCalorieValue(
                "Active Calories",
                value: energy.active,
                energyUnit: energyUnit,
                isLoading: isLoading
            )
            AccessibleCalorieValue(
                "Resting Calories",
                value: energy.resting,
                energyUnit: energyUnit,
                isLoading: isLoading
            )
            if energy.restingRemaining > 0 {
                AccessibleCalorieValue(
                    "Projected resting calories",
                    value: energy.restingRemaining,
                    energyUnit: energyUnit,
                    isLoading: isLoading
                )
            }
            if !isLoading, let visibleGoalReached, !energy.isEmpty {
                Text(visibleGoalReached ? "Goal reached" : "Goal not reached")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Color("TextColor"))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

/// One labeled calorie value for accessibility.
private struct AccessibleCalorieValue: View {

    /// Localized label for the value.
    let label: LocalizedStringKey

    /// Calorie amount rendered with the label.
    let value: Int

    /// Unit label appended to the amount.
    let energyUnit: String

    /// Whether the amount is still loading.
    let isLoading: Bool

    init(_ label: LocalizedStringKey, value: Int, energyUnit: String, isLoading: Bool) {
        self.label = label; self.value = value
        self.energyUnit = energyUnit; self.isLoading = isLoading
    }

    /// Shows one value as a combined accessibility element.
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.headline)
            Text(verbatim: "\(value.formatted(.number)) \(energyUnit)")
                .font(.title3.monospacedDigit())
                .redacted(reason: isLoading ? .placeholder : [])
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

}
