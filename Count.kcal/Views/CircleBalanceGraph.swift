import SwiftUI

/// Burned and consumed energy in rings for Now or Midnight.
struct CircleBalanceGraph: View {

    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var settings: Settings
    @Environment(HealthInterface.self) private var day

    var lineWidth: CGFloat = 8
    let mode: GraphMode
    var accentedWidget = false
    var rendering: CalorieCircleGraph.Rendering = .live
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

    private var palette: CalorieCirclePalette {
        var palette = CalorieCirclePalette(
            burned: settings.burnedColor,
            consumed: settings.consumedColor,
            empty: settings.getGraphEmptyColor(scheme)
        )
        if accentedWidget {
            palette.resting.opacity = 0.85
            palette.prediction.opacity = 0.45
            palette.consumed.opacity = 0.6
            palette.empty.opacity = 0.25
        }
        return palette
    }

}
