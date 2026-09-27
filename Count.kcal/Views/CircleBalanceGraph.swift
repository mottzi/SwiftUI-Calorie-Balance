import SwiftUI

struct CircleBalanceGraph: View {
    @Environment(\.colorScheme) private var scheme

    @EnvironmentObject private var AppSettings: Settings

    @Environment(HealthInterface.self) private var DataViewModel
    
    let trimRatio = 0.25
    var lineWidth: CGFloat = 8
    
    let mode: GraphMode
    
    var body: some View {
        if mode == .midnight {
            GeometryReader { geo in
                ZStack {
                    // base
                    CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                        .brightness(level: .primary)
                    
                    // passive future
                    CircleProgressView(
                        progress: graph.passiveFutureMidnight,
                        color: AppSettings.burnedColor,
                        lineWidth: lineWidth
                    )
                        .brightness(level: .tertiary, to: .circlegraphMidnight)
                    
                    // passive
                    CircleProgressView(progress: graph.passiveMidnight, color: AppSettings.burnedColor, lineWidth: lineWidth)
                        .brightness(level: .secondary, to: .circlegraphMidnight)
                    
                    // active
                    CircleProgressView(progress: graph.activeMidnight, color: AppSettings.burnedColor, lineWidth: lineWidth)
                        .brightness(level: .primary, to: .circlegraphMidnight)
                    
                    // base
                    CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                        .frame(
                            width: geo.size.width - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25),
                            height: geo.size.height - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25)
                        )
                        .brightness(level: .primary)
                    
                    // consumed
                    CircleProgressView(progress: graph.consumedMidnight, color: AppSettings.consumedColor, lineWidth: lineWidth)
                        .frame(
                            width: geo.size.width - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25),
                            height: geo.size.height - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25)
                        )
                        .brightness(level: .primary)
                }
                .saturation(Settings.baseSaturation)
                .brightness(scheme == .dark ? -0.1 : 0.0)
            }
            .padding(lineWidth / 2)
        } else {
            GeometryReader { geo in
                ZStack {
                    // base
                    CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                        .brightness(level: .primary)
                    
                    // passive
                    CircleProgressView(progress: graph.passiveNow, color: AppSettings.burnedColor, lineWidth: lineWidth)
                        .brightness(level: .secondary, to: .circlegraphNow)
                    
                    // active
                    CircleProgressView(progress: graph.activeNow, color: AppSettings.burnedColor, lineWidth: lineWidth)
                        .brightness(level: .primary, to: .circlegraphNow)
                    
                    // base
                    CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                        .frame(
                            width: geo.size.width - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25),
                            height: geo.size.height - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25)
                        )
                        .brightness(level: .primary)
                    
                    // consumed
                    CircleProgressView(progress: graph.consumedNow, color: AppSettings.consumedColor, lineWidth: lineWidth)
                        .frame(
                            width: geo.size.width - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25),
                            height: geo.size.height - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25)
                        )
                        .brightness(level: .primary)
                }
                .geometryGroup()
                .saturation(Settings.baseSaturation)
                .brightness(scheme == .dark ? -0.1 : 0.0)
            }
            .padding(lineWidth / 2)
        }
    }
}

extension CircleBalanceGraph {

    private var graph: GraphCalculations { GraphCalculations(sample: DataViewModel.sample) }

}

enum GraphMode {
    case now
    case midnight
}
