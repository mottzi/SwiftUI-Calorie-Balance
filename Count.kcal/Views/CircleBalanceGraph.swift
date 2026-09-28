import SwiftUI

struct CircleBalanceGraph: View {

    @Environment(\.colorScheme) private var scheme

    @EnvironmentObject private var AppSettings: Settings

    @Environment(HealthInterface.self) private var DataViewModel
    
    let trimRatio = 0.25
    var lineWidth: CGFloat = 8
    
    let mode: GraphMode

    var groupNowGeometry = true

    private var now: EnergyBalance { DataViewModel.sample.now }
    private var midnight: EnergyBalance { DataViewModel.sample.midnight }
    
    var body: some View {
        if mode == .midnight {
            GeometryReader { geo in
                ZStack {
                    // base
                    CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                        .brightness(level: .primary)
                    
                    // passive future
                    CircleProgressView(
                        progress: midnight.ratio(of: midnight.burned),
                        color: AppSettings.burnedColor,
                        lineWidth: lineWidth
                    )
                        .brightness(level: .tertiary, to: .circlegraphMidnight)
                    
                    // passive
                    CircleProgressView(
                        progress: midnight.ratio(of: midnight.active + midnight.resting),
                        color: AppSettings.burnedColor,
                        lineWidth: lineWidth
                    )
                        .brightness(level: .secondary, to: .circlegraphMidnight)
                    
                    // active
                    CircleProgressView(
                        progress: midnight.ratio(of: midnight.active),
                        color: AppSettings.burnedColor,
                        lineWidth: lineWidth
                    )
                        .brightness(level: .primary, to: .circlegraphMidnight)
                    
                    // base
                    CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                        .frame(
                            width: geo.size.width - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25),
                            height: geo.size.height - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25)
                        )
                        .brightness(level: .primary)
                    
                    // consumed
                    CircleProgressView(
                        progress: midnight.ratio(of: midnight.consumed),
                        color: AppSettings.consumedColor,
                        lineWidth: lineWidth
                    )
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
                let rings = ZStack {
                    // base
                    CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                        .brightness(level: .primary)
                    
                    // passive
                    CircleProgressView(
                        progress: now.ratio(of: now.burned),
                        color: AppSettings.burnedColor,
                        lineWidth: lineWidth
                    )
                        .brightness(level: .secondary, to: .circlegraphNow)
                    
                    // active
                    CircleProgressView(
                        progress: now.ratio(of: now.active),
                        color: AppSettings.burnedColor,
                        lineWidth: lineWidth
                    )
                        .brightness(level: .primary, to: .circlegraphNow)
                    
                    // base
                    CircleProgressView(progress: 1, color: AppSettings.getGraphEmptyColor(scheme), lineWidth: lineWidth)
                        .frame(
                            width: geo.size.width - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25),
                            height: geo.size.height - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25)
                        )
                        .brightness(level: .primary)
                    
                    // consumed
                    CircleProgressView(
                        progress: now.ratio(of: now.consumed),
                        color: AppSettings.consumedColor,
                        lineWidth: lineWidth
                    )
                        .frame(
                            width: geo.size.width - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25),
                            height: geo.size.height - (scheme == .dark ? lineWidth * 2.5 : lineWidth * 2.25)
                        )
                        .brightness(level: .primary)
                }

                Group {
                    if groupNowGeometry {
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

}

enum GraphMode {

    case now
    case midnight

}
