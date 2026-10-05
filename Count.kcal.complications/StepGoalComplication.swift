import SwiftUI
import WidgetKit

/// Step count, remaining steps, and progress toward the saved daily goal.
struct StepGoalComplication: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Goals.steps", provider: GoalComplicationTimelineProvider()) { entry in
            StepGoalComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .accessibilityHint(entry.isSampleData ? Text("Sample Data") : Text(""))
        }
        .configurationDisplayName("Step goal")
        .description("Today's steps, your daily goal, and the steps still to go.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
        .contentMarginsDisabled()
    }

}

struct StepGoalComplicationView: View {

    @Environment(\.widgetFamily) private var family

    let entry: GoalComplicationEntry

    var body: some View {
        Group {
            if family == .accessoryCircular {
                ZStack {
                    ComplicationProgressRing(fraction: entry.steps.fraction, color: color)
                    VStack(spacing: 1) {
                        Image(systemName: entry.steps.isComplete ? "checkmark" : "figure.walk")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color)
                            .widgetAccentable()
                        Text(entry.data.steps.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))))
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .padding(.horizontal, 5)
                }
            } else {
                rectangular
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

}

extension StepGoalComplicationView {

    private var rectangular: some View {
        HStack(spacing: 10) {
            ZStack {
                ComplicationProgressRing(fraction: entry.steps.fraction, color: color, lineWidth: 5)
                Image(systemName: entry.steps.isComplete ? "checkmark" : "figure.walk")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(color)
                    .widgetAccentable()
                if entry.stepsGoal > 0 {
                    Text(entry.steps.fraction, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .offset(y: 26)
                }
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 1) {
                Text("Steps today")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                    .widgetAccentable()
                Text(entry.data.steps.formatted())
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(remainingLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Group {
                    if entry.stepsGoal > 0 {
                        Text("Goal \(entry.stepsGoal.formatted())")
                    } else {
                        Text("Set a step goal")
                    }
                }
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
    }

    private var color: Color { Settings.shared.burnedColor.brighten(0.25) }

    private var remainingLabel: String {
        guard let remaining = entry.steps.remaining else { return String(localized: "No goal") }
        if remaining == 0 { return String(localized: "Goal reached") }
        return String(localized: "\(remaining.formatted()) to go")
    }

    private var accessibilitySummary: Text {
        if let remaining = entry.steps.remaining {
            Text("\(entry.data.steps) steps today, goal \(entry.stepsGoal), \(remaining) steps to go")
        } else {
            Text("\(entry.data.steps) steps today, no step goal set")
        }
    }

}

#Preview(as: .accessoryRectangular) { StepGoalComplication() } timeline: { GoalComplicationEntry.preview }
#Preview(as: .accessoryCircular) { StepGoalComplication() } timeline: { GoalComplicationEntry.preview }
