import SwiftUI
import WidgetKit

struct CircleBalanceGraphWatch: View {

    @Environment(\.colorScheme) private var scheme

    @EnvironmentObject var AppSettings: Settings

    @Environment(HealthInterface.self) var DataInterface
    
    var mode: GraphMode
    var rendering: WidgetRenderingMode = .fullColor
    var context: GraphContext = .app
    var cutout = 0.28

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width, geo.size.height)

            CalorieCircleGraph(
                energy: mode == .now ? now : midnight,
                configuration: CalorieCircleConfiguration(
                    lineWidth: lineWidth(max: width),
                    ringSpacing: gapWidth(max: width) / 2,
                    openAngle: .degrees(cutout * 360),
                    segmentGap: 0
                ),
                palette: palette,
                rendering: context == .app || context == .toolbar ? .live : .widget
            )
            .frame(maxWidth: .infinity)
        }
    }

}

extension CircleBalanceGraphWatch {

    private func lineWidth(max: CGFloat) -> CGFloat {
        switch context {
            case .app: max * 0.08
            case .toolbar: max * 0.13
            case .circle: 4
            case .circleFull: 8
            case .circleFuller: 10
            case .circleThick: 6
        }
    }

    private func gapWidth(max: CGFloat) -> CGFloat {
        switch context {
            case .app, .toolbar: lineWidth(max: max) * 0.5
            case .circle: 2
            case .circleFull, .circleFuller: 4
            case .circleThick: 5
        }
    }

}

extension CircleBalanceGraphWatch {

    private var palette: CalorieGraphPalette {

        var palette = CalorieGraphPalette(
            burned: AppSettings.burnedColor,
            consumed: AppSettings.consumedColor,
            empty: AppSettings.getGraphEmptyColor(scheme)
        )

        if rendering != .fullColor {
            palette.resting.opacity = 0.7
            palette.prediction.color = .white.opacity(0.74)
            palette.prediction.opacity = 0.4
            palette.empty.opacity = 0.2
        }

        return palette
    }

    private var now: EnergyBalance { DataInterface.sample.now }
    private var midnight: EnergyBalance { DataInterface.sample.midnight }

}

enum GraphContext {
    case app
    case toolbar
    case circle
    case circleThick
    case circleFull
    case circleFuller
}
