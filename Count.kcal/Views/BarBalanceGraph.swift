import SwiftUI
import WidgetKit

/// Recorded or projected energy in two horizontal bars.
struct BarBalanceGraph: View {

    @Environment(\.colorScheme) private var scheme: ColorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(HealthInterface.self) private var day

    @EnvironmentObject private var settings: Settings

    let mode: GraphMode
    let labels: Bool
    let animateNumericValues: Bool
    var rendering: CalorieGraphRendering = .live

    init(
        mode: GraphMode,
        labels: Bool = true,
        animateNumericValues: Bool = false,
        rendering: CalorieGraphRendering = .live
    ) {
        self.mode = mode
        self.labels = labels
        self.animateNumericValues = animateNumericValues
        self.rendering = rendering
    }
    
    var body: some View {
        let energy = mode == .now ? day.sample.now : day.sample.midnight

        CalorieBarGraph(
            energy: energy,
            configuration: CalorieBarConfiguration(
                rowSpacing: scheme == .light ? 1 : 2,
                showsLabels: labels,
                animatesNumericValues: animateNumericValues
            ),
            palette: palette,
            rendering: rendering,
            projectedRestingLabel: rendering == .widget ? day.sample.midnight.restingRemaining : nil
        )
        .padding(.bottom, scheme == .light ? 1 : 0)
    }

}

extension BarBalanceGraph {

    private var palette: CalorieGraphPalette {
        var palette = CalorieGraphPalette(
            burned: settings.burnedColor,
            consumed: settings.consumedColor,
            empty: settings.getGraphEmptyColor(scheme)
        )
        if renderingMode == .accented {
            palette.applyAccentedAppearance()
            palette.prediction.opacity = 0.7
        } else {
            palette.empty.opacity = scheme == .light ? 0.4 : 1
        }
        return palette
    }

}
