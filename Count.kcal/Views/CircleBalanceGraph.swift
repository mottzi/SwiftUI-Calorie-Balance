import SwiftUI

/// Burned and consumed energy in rings for Now or Midnight.
struct CircleBalanceGraph: View {

    @Environment(\.colorScheme) private var scheme

    @EnvironmentObject private var AppSettings: Settings

    @Environment(HealthInterface.self) private var DataViewModel

    var lineWidth: CGFloat = 8
    let mode: GraphMode
    // Accented widgets replace colors with white but retain each ring's opacity.
    var accentedWidget = false

    var body: some View {
        GeometryReader { geo in
            let energy = mode == .now ? DataViewModel.sample.now : DataViewModel.sample.midnight
            let innerInset = scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25

            // Keep color effects in one rendering path; a geometry group clips brightened channels.
            ZStack {
                // base
                CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                    .brightness(level: .primary, to: .bargraph)
                    .opacity(accentedWidget ? 0.25 : 1)

                // Keep the projection's identity so its arc animates with the recorded rings.
                CircleProgressView(
                    progress: energy.ratio(of: energy.burned),
                    color: AppSettings.burnedColor,
                    lineWidth: lineWidth
                )
                .brightness(level: .tertiary, to: .circlegraphMidnight)
                .opacity(mode == .now ? 0 : accentedWidget ? 0.45 : 1)

                // passive
                CircleProgressView(
                    progress: energy.ratio(of: energy.active + energy.resting),
                    color: AppSettings.burnedColor,
                    lineWidth: lineWidth
                )
                .brightness(level: .secondary, to: .circlegraphMidnight)
                .opacity(accentedWidget ? 0.85 : 1)

                // active
                CircleProgressView(
                    progress: energy.ratio(of: energy.active),
                    color: AppSettings.burnedColor,
                    lineWidth: lineWidth
                )
                .brightness(level: .primary, to: .circlegraphMidnight)

                // base
                CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                    .frame(width: geo.size.width - innerInset, height: geo.size.height - innerInset)
                    .brightness(level: .primary, to: .bargraph)
                    .opacity(accentedWidget ? 0.25 : 1)

                // consumed
                CircleProgressView(
                    progress: energy.ratio(of: energy.consumed),
                    color: AppSettings.consumedColor,
                    lineWidth: lineWidth
                )
                .frame(width: geo.size.width - innerInset, height: geo.size.height - innerInset)
                .brightness(level: .primary, to: .bargraph)
                .opacity(accentedWidget ? 0.6 : 1)
            }

            .graphColorAppearance()
        }
        .padding(lineWidth / 2)
    }

}

/// Time used for calorie balance graphs.
enum GraphMode {

    case now
    case midnight

}
