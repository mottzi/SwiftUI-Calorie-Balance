import SwiftUI
import WidgetKit

/// Estimated calories left after the saved loss or gain goal.
struct CalorieRoomComplication: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Goals.calorieRoom", provider: GoalComplicationTimelineProvider()) { entry in
            CalorieRoomComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .accessibilityHint(entry.isSampleData ? Text("Sample Data") : Text(""))
        }
        .configurationDisplayName("Calorie room")
        .description("Estimated calories left for today, adjusted for your weight goal. Updates as you eat and move.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
        .contentMarginsDisabled()
    }

}

struct CalorieRoomComplicationView: View {

    @Environment(\.widgetFamily) private var family

    let entry: GoalComplicationEntry

    var body: some View {
        Group {
            if family == .accessoryCircular {
                circular
            } else {
                rectangular
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Calorie room"))
        .accessibilityValue(accessibilitySummary)
    }

}

extension CalorieRoomComplicationView {

    private var circular: some View {
        ZStack {
            ComplicationProgressRing(fraction: entry.budget.progress.fraction, color: color)
            VStack(spacing: 0) {
                Image(systemName: isOver ? "plus" : "fork.knife")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(color)
                    .widgetAccentable()
                Text(entry.budget.remaining.map { abs($0).formatted() } ?? "–")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                Text(entry.budget.remaining == nil ? LocalizedStringKey("No estimate") : isOver ? "over" : "left")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 5)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                Text("Calorie room")
                Spacer(minLength: 0)
                Image(systemName: "moon.stars.fill")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .widgetAccentable()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.budget.remaining.map { abs($0).formatted() } ?? "–")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                Group {
                    if entry.budget.remaining == nil {
                        Text("No estimate")
                    } else if isOver {
                        Text("\(entry.energyUnit) over")
                    } else {
                        Text("\(entry.energyUnit) left")
                    }
                }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.65)

            ComplicationSegmentedMeter(fraction: entry.budget.progress.fraction, color: color)

            HStack {
                Text("\(entry.data.consumed.formatted()) eaten")
                Spacer(minLength: 2)
                if entry.budget.remaining != nil {
                    Text("\(entry.budget.allowance.formatted()) budget")
                }
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 2)
    }

    private var isOver: Bool { (entry.budget.remaining ?? 0) < 0 }
    private var color: Color { isOver ? Settings.shared.consumedColor : Settings.shared.burnedColor.brighten(0.25) }

    private var accessibilitySummary: Text {
        if let remaining = entry.budget.remaining {
            if isOver {
                Text("Estimated \(abs(remaining)) \(entry.energyUnit) over budget")
            } else {
                Text("Estimated \(remaining) \(entry.energyUnit) left")
            }
        } else {
            Text("No energy estimate available")
        }
    }

}

#Preview(as: .accessoryRectangular) { CalorieRoomComplication() } timeline: { GoalComplicationEntry.preview }
#Preview(as: .accessoryCircular) { CalorieRoomComplication() } timeline: { GoalComplicationEntry.preview }
