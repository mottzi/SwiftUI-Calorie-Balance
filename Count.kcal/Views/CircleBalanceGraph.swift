import SwiftUI

/// Burned and consumed energy in rings for Now or Midnight.
struct CircleBalanceGraph: View {

    @Environment(\.colorScheme) private var scheme

    @EnvironmentObject private var AppSettings: Settings

    @Environment(HealthInterface.self) private var DataViewModel

    var lineWidth: CGFloat = 8
    let mode: GraphMode
    var groupNowGeometry = true

    var body: some View {
        GeometryReader { geo in
            let energy = mode == .now ? DataViewModel.sample.now : DataViewModel.sample.midnight
            let context: BrightnessContext = mode == .now ? .circlegraphNow : .circlegraphMidnight
            let innerInset = scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25

            let rings = ZStack {
                // base
                CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                    .brightness(level: .primary)

                if mode == .midnight {
                    // passive future
                    CircleProgressView(
                        progress: energy.ratio(of: energy.burned),
                        color: AppSettings.burnedColor,
                        lineWidth: lineWidth
                    )
                    .brightness(level: .tertiary, to: context)
                }

                // passive
                CircleProgressView(
                    progress: energy.ratio(of: energy.active + energy.resting),
                    color: AppSettings.burnedColor,
                    lineWidth: lineWidth
                )
                .brightness(level: .secondary, to: context)

                // active
                CircleProgressView(
                    progress: energy.ratio(of: energy.active),
                    color: AppSettings.burnedColor,
                    lineWidth: lineWidth
                )
                .brightness(level: .primary, to: context)

                // base
                CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                    .frame(width: geo.size.width - innerInset, height: geo.size.height - innerInset)
                    .brightness(level: .primary)

                // consumed
                CircleProgressView(
                    progress: energy.ratio(of: energy.consumed),
                    color: AppSettings.consumedColor,
                    lineWidth: lineWidth
                )
                .frame(width: geo.size.width - innerInset, height: geo.size.height - innerInset)
                .brightness(level: .primary)
            }

            Group {
                if mode == .now && groupNowGeometry {
                    rings.geometryGroup()
                } else {
                    rings
                }
            }
            .saturation(Settings.baseSaturation)
            .brightness(scheme == .dark ? -0.1 : 0.0)
        }
        .padding(lineWidth / 2)
    }

}

/// Time used for calorie balance graphs.
enum GraphMode {

    case now
    case midnight

}
