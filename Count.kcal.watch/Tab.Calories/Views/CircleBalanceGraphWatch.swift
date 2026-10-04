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
            ZStack {
                // base
                CircleProgressView(
                    progress: 1,
                    color: AppSettings.getGraphEmptyColor(scheme),
                    cutout: cutout,
                    lineWidth: lineWidth(max: geo.size.width)
                )
                    .brightness(level: .primary)
                    .frame(width: geo.size.width - lineWidth(max: geo.size.width))
                    .opacity(rendering == .fullColor ? 1 : 0.2)

                // passive future
                CircleProgressView(
                    progress: mode == .now ? now.ratio(of: now.burned) : midnight.ratio(of: midnight.burned),
                    color: rendering == .fullColor ? AppSettings.burnedColor : Color.white.opacity(mode == .now ? 0 : 0.74),
                    cutout: cutout,
                    lineWidth: lineWidth(max: geo.size.width)
                )
                    .brightness(level: .tertiary, to: .circlegraphMidnight)
                    .frame(width: geo.size.width - lineWidth(max: geo.size.width))
                    .opacity(rendering == .fullColor ? 1 : 0.4)
                    .opacity(mode == .now ? 0 : 1)
                
                // passive
                CircleProgressView(
                    progress: mode == .now
                        ? now.ratio(of: now.burned)
                        : midnight.ratio(of: midnight.active + midnight.resting),
                    color: AppSettings.burnedColor,
                    cutout: cutout,
                    lineWidth: lineWidth(max: geo.size.width)
                )
                    .brightness(level: .secondary, to: .circlegraphMidnight)
                    .frame(width: geo.size.width - lineWidth(max: geo.size.width))
                    .opacity(rendering == .fullColor ? 1 : 0.7)
                                    
                // active
                CircleProgressView(
                    progress: mode == .now ? now.ratio(of: now.active) : midnight.ratio(of: midnight.active),
                    color: AppSettings.burnedColor,
                    cutout: cutout,
                    lineWidth: lineWidth(max: geo.size.width)
                )
                    .brightness(level: .primary, to: .circlegraphMidnight)
                    .frame(width: geo.size.width - lineWidth(max: geo.size.width))

                // base
                CircleProgressView(
                    progress: 1,
                    color: AppSettings.getGraphEmptyColor(scheme),
                    cutout: cutout,
                    lineWidth: lineWidth(max: geo.size.width)
                )
                    .frame(width: geo.size.width - (3 * lineWidth(max: geo.size.width)) - gapWidth(max: geo.size.width))
                    .brightness(level: .primary)
                    .opacity(rendering == .fullColor ? 1 : 0.2)
                
                // consumed
                CircleProgressView(
                    progress: mode == .now ? now.ratio(of: now.consumed) : midnight.ratio(of: midnight.consumed),
                    color: AppSettings.consumedColor,
                    cutout: cutout,
                    lineWidth: lineWidth(max: geo.size.width)
                )
                    .frame(width: geo.size.width - (3 * lineWidth(max: geo.size.width)) - gapWidth(max: geo.size.width))
                    .brightness(level: .primary)
            }
            .frame(maxWidth: .infinity)
            .saturation(Settings.baseSaturation)
            .brightness(scheme == .dark ? -0.1 : 0.0)
        }
    }

}

extension CircleBalanceGraphWatch {

    func lineWidth(max: CGFloat) -> CGFloat {
        switch context {
            case .app: max * 0.08
            case .circle: 4
            case .circleFull: 8
            case .circleFuller: 10
            case .circleThick: 6
        }
    }

    func gapWidth(max: CGFloat) -> CGFloat {
        switch context {
            case .app: lineWidth(max: max) * 0.5
            case .circle: 2
            case .circleFull, .circleFuller: 4
            case .circleThick: 5
        }
    }

}

extension CircleBalanceGraphWatch {

    private var now: EnergyBalance { DataInterface.sample.now }
    private var midnight: EnergyBalance { DataInterface.sample.midnight }

}

enum GraphContext {
    case app
    case circle
    case circleThick
    case circleFull
    case circleFuller
}
