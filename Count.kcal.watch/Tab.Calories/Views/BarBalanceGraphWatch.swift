import SwiftUI

/// Watch balance bar for recorded or projected energy.
struct BarBalanceGraphWatch: View {

    let mode: GraphMode

    var body: some View {

        GeometryReader { container in
            VStack(spacing: 2) {
                GeometryReader { geometry in
                    BarBalanceGraphWatchTop(mode: mode, geometry: geometry)
                }
                .frame(height: container.size.height / 2 - 1)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 6,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 6
                    )
                )

                GeometryReader { geometry in
                    BarBalanceGraphWatchBottom(mode: mode, geometry: geometry)
                }
                .frame(height: container.size.height / 2 - 1)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 6,
                        bottomTrailingRadius: 6,
                        topTrailingRadius: 0
                    )
                )
            }
            .saturation(Settings.baseSaturation)
        }
    }

}

/// Burned energy segments for the selected balance mode.
private struct BarBalanceGraphWatchTop: View {

    @EnvironmentObject private var settings: Settings
    @Environment(HealthInterface.self) private var health

    let mode: GraphMode
    let geometry: GeometryProxy

    var body: some View {

        ZStack(alignment: .leading) {
            Rectangle()
                .fill(settings.getGraphEmptyColor(.dark))
                .frame(width: geometry.size.width)
                .overlay {
                    LinearGradient(
                        colors: [.black, settings.getGraphEmptyColor(.dark)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                        .opacity(0.25)
                }

            let energy = self.energy
            let widthActive = CGFloat(energy.ratio(of: energy.active)) * geometry.size.width

            Rectangle()
                .fill(settings.burnedColor)
                .frame(width: widthActive)
                .brightness(level: .primary)
                .overlay {
                    LinearGradient(colors: [.black, settings.burnedColor], startPoint: .bottom, endPoint: .top)
                        .opacity(gradientOpacityDark)
                }

            let widthPassive = CGFloat(energy.ratio(of: energy.resting)) * geometry.size.width

            Rectangle()
                .fill(settings.burnedColor)
                .frame(width: widthPassive)
                .brightness(level: .secondary)
                .overlay {
                    LinearGradient(colors: [.black, settings.burnedColor], startPoint: .bottom, endPoint: .top)
                        .opacity(gradientOpacityDark)
                }
                .clipShape(.rect(topTrailingRadius: mode == .midnight ? 0 : 6))
                .padding(.leading, widthActive)

            if mode == .midnight {
                let widthProjected = CGFloat(energy.ratio(of: energy.restingRemaining)) * geometry.size.width

                Rectangle()
                    .fill(settings.burnedColor)
                    .frame(width: widthProjected)
                    .brightness(level: .tertiary)
                    .overlay {
                        LinearGradient(colors: [.black, settings.burnedColor], startPoint: .bottom, endPoint: .top)
                            .opacity(gradientOpacityDark)
                    }
                    .clipShape(.rect(topTrailingRadius: 6))
                    .padding(.leading, widthActive + widthPassive)

                if energy.burned < energy.graphTotal {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: geometry.size.width - widthActive - widthPassive - widthProjected)
                        .padding(.leading, widthActive + widthPassive + widthProjected)
                }
            }
        }
        .drawingGroup()
    }

}

extension BarBalanceGraphWatchTop {

    private var energy: EnergyBalance {
        switch mode {
            case .now: health.sample.now
            case .midnight: health.sample.midnight
        }
    }

}

/// Consumed energy segment for the selected balance mode.
private struct BarBalanceGraphWatchBottom: View {

    @EnvironmentObject private var settings: Settings
    @Environment(HealthInterface.self) private var health

    let mode: GraphMode
    let geometry: GeometryProxy

    var body: some View {

        ZStack(alignment: .leading) {
            Rectangle()
                .fill(settings.getGraphEmptyColor(.dark))
                .frame(width: geometry.size.width)
                .overlay {
                    LinearGradient(colors: [.blue, settings.getGraphEmptyColor(.dark)], startPoint: .bottom, endPoint: .top)
                        .opacity(0.25)
                }

            let energy = self.energy
            let widthConsumed = CGFloat(energy.ratio(of: energy.consumed)) * geometry.size.width

            Rectangle()
                .fill(settings.consumedColor)
                .frame(width: widthConsumed)
                .brightness(level: .primary)
                .overlay {
                    LinearGradient(colors: [.black, settings.burnedColor], startPoint: .bottom, endPoint: .top)
                        .opacity(gradientOpacityDark)
                }
                .clipShape(.rect(bottomTrailingRadius: 6))

            if mode == .midnight && health.sample.consumed < energy.graphTotal {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: geometry.size.width - widthConsumed)
                    .padding(.leading, widthConsumed)
            }
        }
        .drawingGroup()
    }

}

extension BarBalanceGraphWatchBottom {

    private var energy: EnergyBalance {
        switch mode {
            case .now: health.sample.now
            case .midnight: health.sample.midnight
        }
    }

}

let gradientOpacityDark: Double = 0.20
