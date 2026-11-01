import SwiftUI

/// Toolbar control for the streak count and chart visibility.
struct StreakToolbarButton: View {

    @Environment(Streak.self) private var streak

    @ScaledMetric(relativeTo: .callout) private var countOffset = 1.5

    let color: Color
    let controlsDisabled: Bool

    var body: some View {
        Button {
            streak.toggleStreaksView()
        } label: {
            HStack(spacing: 5) {
                StreakFlameIcon(
                    color: color,
                    isAnimating: streak.hasLoadedCount && streak.streaks > 0 && !controlsDisabled
                )

                Text(verbatim: streak.hasLoadedCount ? streak.streaks.formatted(.number) : "00")
                    .redacted(reason: streak.hasLoadedCount ? [] : .placeholder)
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(Color("TextColor"))
                    .offset(y: countOffset)
            }
        }
        .disabled(controlsDisabled)
        .accessibilityLabel("Streak")
        .accessibilityValue(streak.hasLoadedCount ? Text("\(streak.streaks) days") : Text("Loading streak"))
    }

}
