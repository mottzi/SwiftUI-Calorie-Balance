import SwiftUI

/// Burned and consumed energy in rings for Now or Midnight.
struct CircleBalanceGraph: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(HealthInterface.self) private var day

    @EnvironmentObject private var settings: Settings

    var lineWidth: CGFloat = 8
    let mode: GraphMode
    var accentedWidget = false
    var rendering: CalorieGraphRendering = .live
    var openAngle: Angle = .degrees(90)
    var segmentGap: CGFloat = 2
    var ringSpacing: CGFloat? = nil

    var body: some View {
        CalorieCircleGraph(
            energy: mode == .now ? day.sample.now : day.sample.midnight,
            configuration: CalorieCircleConfiguration(
                lineWidth: lineWidth,
                ringSpacing: ringSpacing ?? lineWidth * (scheme == .dark ? 0.25 : 0.125),
                openAngle: openAngle,
                segmentGap: segmentGap
            ),
            palette: palette,
            rendering: rendering
        )
    }

}

extension CircleBalanceGraph {

    private var palette: CalorieGraphPalette {
        var palette = CalorieGraphPalette(
            burned: settings.burnedColor,
            consumed: settings.consumedColor,
            empty: settings.getGraphEmptyColor(scheme)
        )
        if accentedWidget {
            palette.applyAccentedAppearance()
        }
        return palette
    }

}
