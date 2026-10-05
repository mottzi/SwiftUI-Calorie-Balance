import SwiftUI
import WidgetKit

/// Three nutrient goals in a large slot, with protein in a circular slot.
struct MacroGoalsComplication: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Goals.macros", provider: GoalComplicationTimelineProvider()) { entry in
            MacroGoalsComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .accessibilityHint(entry.isSampleData ? Text("Sample Data") : Text(""))
        }
        .configurationDisplayName("Macro goals")
        .description("Protein, carbs and fats against your saved goals. Round slots focus on protein.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
        .contentMarginsDisabled()
    }

}

struct MacroGoalsComplicationView: View {

    @Environment(\.widgetFamily) private var family

    let entry: GoalComplicationEntry

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                ComplicationProgressRing(
                    fraction: entry.protein.fraction,
                    color: Settings.shared.consumedColor.brighten(0.2)
                )
                VStack(spacing: 0) {
                    Text("Protein")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(entry.data.protein.formatted())
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("g")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Protein, \(entry.data.protein) grams, goal \(entry.proteinGoal) grams"))
        } else {
            HStack(alignment: .top, spacing: 7) {
                MacroGoalDial(title: "Protein", progress: entry.protein, color: Settings.shared.consumedColor.brighten(0.2))
                MacroGoalDial(title: "Carbs", progress: entry.carbs, color: .cyan)
                MacroGoalDial(title: "Fats", progress: entry.fats, color: Settings.shared.burnedColor.brighten(0.3))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }

}

private struct MacroGoalDial: View {

    let title: LocalizedStringKey
    let progress: ComplicationGoalProgress
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            ZStack {
                ComplicationProgressRing(fraction: progress.fraction, color: color, lineWidth: 3.5)
                Text(progress.amount.formatted())
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
            .aspectRatio(1, contentMode: .fit)
            Group {
                if progress.goal > 0 {
                    Text("of \(progress.goal) g")
                } else {
                    Text("No goal")
                }
            }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Text(title)), \(progress.amount) grams, goal \(progress.goal) grams"))
    }

}

#Preview(as: .accessoryRectangular) { MacroGoalsComplication() } timeline: { GoalComplicationEntry.preview }
#Preview(as: .accessoryCircular) { MacroGoalsComplication() } timeline: { GoalComplicationEntry.preview }
