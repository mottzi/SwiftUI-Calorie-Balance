import SwiftUI

/// The dashboard's flame size, motion, and count typography, without a chart action.
struct SharingStreakBadge: View {
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .callout) private var countOffset = 1.5
    let streak: CalorieCardSnapshot.StreakSummary
    var placement = Placement.toolbar

    enum Placement {
        case toolbar
        case overview
    }

    var body: some View {
        HStack(spacing: 5) {
            if placement == .overview {
                count.monospacedDigit()
                flame
            } else {
                flame
                count
            }
        }
        .fixedSize()
        // Match the native horizontal content insets of the dashboard's toolbar button.
        .padding(.horizontal, placement == .toolbar ? 8 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak")
        .accessibilityValue(Text("\(streak.days) days"))
    }

    private var flame: some View {
        StreakFlameIcon(color: streak.days > 0 ? streak.color.color(in: scheme) : .secondary, isAnimating: streak.days > 0)
    }

    private var count: some View {
        Text(streak.days, format: .number)
            .font(.callout.bold())
            .foregroundStyle(.primary)
            .offset(y: countOffset)
    }

}
