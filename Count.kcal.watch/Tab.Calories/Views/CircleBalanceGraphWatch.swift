import SwiftUI
import WidgetKit

/// Burned and consumed energy rings sized for the watch app or its complications.
struct CircleBalanceGraphWatch: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(HealthInterface.self) private var day

    @EnvironmentObject private var settings: Settings
    
    var mode: GraphMode
    var rendering: WidgetRenderingMode = .fullColor
    var context: GraphContext = .app
    var cutout = 0.28

    var body: some View {
        if context == .app {
            WatchCalorieDashboardRing(
                energy: mode == .now ? day.sample.now : day.sample.midnight,
                palette: palette,
                cutout: cutout
            )
        } else {
            GeometryReader { geometry in
                let diameter = min(geometry.size.width, geometry.size.height)

                CalorieCircleGraph(
                    energy: mode == .now ? day.sample.now : day.sample.midnight,
                    configuration: CalorieCircleConfiguration(
                        lineWidth: lineWidth(for: diameter),
                        ringSpacing: ringSpacing(for: diameter),
                        openAngle: .degrees(cutout * 360)
                    ),
                    palette: palette,
                    rendering: context == .app || context == .toolbar ? .live : .widget
                )
                .frame(width: diameter, height: diameter)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

}

extension CircleBalanceGraphWatch {

    private func lineWidth(for diameter: CGFloat) -> CGFloat {
        switch context {
            case .app: diameter * 0.08
            case .toolbar: diameter * 0.13
            case .circle: 4
            case .circleFull: 8
            case .circleFuller: 10
            case .circleThick: 6
        }
    }

    private func ringSpacing(for diameter: CGFloat) -> CGFloat {
        switch context {
            case .app, .toolbar: lineWidth(for: diameter) * 0.25
            case .circle: 1
            case .circleFull, .circleFuller: 2
            case .circleThick: 2.5
        }
    }

}

extension CircleBalanceGraphWatch {

    private var palette: CalorieGraphPalette {

        var palette = CalorieGraphPalette(
            burned: settings.burnedColor,
            consumed: settings.consumedColor,
            empty: settings.getGraphEmptyColor(scheme)
        )

        if rendering != .fullColor {
            palette.resting.opacity = 0.7
            palette.prediction.color = .white.opacity(0.74)
            palette.prediction.opacity = 0.4
            palette.empty.opacity = 0.2
        }

        return palette
    }

}

/// Watch graph positions and complication sizes.
enum GraphContext {
    case app
    case toolbar
    case circle
    case circleThick
    case circleFull
    case circleFuller
}
