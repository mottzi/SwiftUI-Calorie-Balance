import SwiftUI

struct NutrientsCard: View {

    @Environment(\.dynamicTypeSize) private var dynamicType

    @EnvironmentObject private var settings: Settings

    var body: some View {
        Card("Nutrients") {
            VStack(spacing: 12) {
                MacroSlider()
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)

                let layout = dynamicType.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    NutrientGoalLabel(title: "Carbs", grams: settings.carbsGoal, ratio: settings.carbsRatio, color: .orange)
                    if !dynamicType.isAccessibilitySize { Spacer() }
                    NutrientGoalLabel(
                        title: "Fats",
                        grams: settings.fatsGoal,
                        ratio: settings.fatsRatio,
                        color: Color(red: 217/255, green: 220/255, blue: 214/255)
                    )
                    if !dynamicType.isAccessibilitySize { Spacer() }
                    NutrientGoalLabel(
                        title: "Protein",
                        grams: settings.proteinGoal,
                        ratio: settings.proteinRatio,
                        color: .red
                    )
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 4)
    }

}

/// One goal reads only its own amount, share, and appearance.
private struct NutrientGoalLabel: View {

    @Environment(\.dynamicTypeSize) private var dynamicType

    let title: LocalizedStringKey
    let grams: Int
    let ratio: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("TextColor"))
                .fixedSize(horizontal: !dynamicType.isAccessibilitySize, vertical: true)

            HStack(spacing: 4) {
                Text(grams, format: .number.grouping(.never))
                    .font(.subheadline.bold())
                    .foregroundStyle(color.gradient)
                    .layoutPriority(1)

                Text(verbatim: "g")
                    .font(.caption.weight(.thin))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color("TextColor"))
            }

            if dynamicType.isAccessibilitySize {
                Text(ratio, format: .percent.precision(.fractionLength(0)))
                    .font(.caption)
                    .foregroundStyle(Color("SecondaryTextColor"))
            }
        }
        .lineLimit(dynamicType.isAccessibilitySize ? nil : 1)
        .accessibilityElement(children: .combine)
    }

}

#Preview {
    NavigationStack {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
