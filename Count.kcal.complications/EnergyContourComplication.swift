import SwiftUI
import WidgetKit

/// Daily intake and expenditure with a separate midnight estimate.
struct EnergyContourComplication: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Energy.contour", provider: EnergyContourTimelineProvider()) { entry in
            EnergyContourComplicationView(entry: entry)
                .healthSnapshotAvailability(isUnavailable: entry.isUnavailable)
                .containerBackground(.clear, for: .widget)
                .accessibilityHint(entry.isSampleData
                    ? Text("Sample data. Dashed lines are estimates.")
                    : Text("Dashed lines are estimates."))
        }
        .configurationDisplayName("Energy contour")
        .description("Today's intake and expenditure in one contour, with a midnight estimate.")
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }

}

struct EnergyContourComplicationView: View {

    let entry: EnergyContourEntry

    var body: some View {
        VStack(spacing: 1) {
            headline
            if entry.contour.hasData {
                EnergyContourDrawing(contour: entry.contour, burned: burned, consumed: consumed)
                legend
            } else {
                empty
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Energy contour"))
        .accessibilityValue(accessibilitySummary)
    }

}

extension EnergyContourComplicationView {

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if let remaining = entry.contour.budget.remaining {
                Text(abs(remaining).formatted())
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                Group {
                    if remaining < 0 { Text("\(entry.energyUnit) over") }
                    else { Text("\(entry.energyUnit) left") }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            } else {
                Text("No estimate")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
            Spacer(minLength: 2)
            Image(systemName: "moon.fill")
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var legend: some View {
        HStack(spacing: 3) {
            Text("00")
                .font(.system(size: 7, design: .monospaced))
            Spacer(minLength: 0)
            Capsule().fill(consumed).frame(width: 7, height: 1.4)
            Text("Eaten")
            Spacer(minLength: 5).frame(maxWidth: 8)
            Capsule().fill(burned).frame(width: 7, height: 1.4).widgetAccentable()
            if entry.contour.isBurnEstimated { Text("Estimated burn") }
            else { Text("Burned") }
            Spacer(minLength: 0)
            Text("24")
                .font(.system(size: 7, design: .monospaced))
        }
        .font(.system(size: 7, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var empty: some View {
        VStack(spacing: 7) {
            Rectangle().fill(.quaternary).frame(height: 0.5)
            Text("No energy data")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private var burned: Color { Settings.shared.burnedColor.brighten(0.25) }
    private var consumed: Color { Settings.shared.consumedColor.brighten(0.1) }

    private var accessibilitySummary: Text {

        let eaten = Int(entry.contour.current.consumed.rounded())
        let burned = Int(entry.contour.current.burned.rounded())
        return if let remaining = entry.contour.budget.remaining {
            if remaining < 0 {
                Text("Estimated \(abs(remaining)) \(entry.energyUnit) over budget. Intake \(eaten), expenditure \(burned).")
            } else {
                Text("Estimated \(remaining) \(entry.energyUnit) left. Intake \(eaten), expenditure \(burned).")
            }
        } else {
            Text("Intake \(eaten) \(entry.energyUnit). No energy estimate available.")
        }
    }

}

#Preview(as: .accessoryRectangular) { EnergyContourComplication() } timeline: { EnergyContourEntry.preview }
