import SwiftUI

/// Shows recorded or projected energy in two horizontal bars.
struct BarBalanceGraph: View {

    @Environment(\.colorScheme) private var scheme: ColorScheme
    @Environment(HealthInterface.self) private var day

    let mode: GraphMode
    let labels: Bool
    let animateNumericValues: Bool

    init(mode: GraphMode, labels: Bool = true, animateNumericValues: Bool = false) {
        self.mode = mode
        self.labels = labels
        self.animateNumericValues = animateNumericValues
    }
    
    var body: some View {
        let energy = mode == .now ? day.sample.now : day.sample.midnight

        GeometryReader { container in
            VStack(spacing: scheme == .light ? 1 : 2) {
                GeometryReader { geometry in
                    BarBalanceGraphTopRow(geometry: geometry, energy: energy, mode: mode, labels: labels, animateNumericValues: animateNumericValues)
                }
                .frame(height: container.size.height / 2 - 1)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 6,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 6,
                    style: .continuous
                ))
                
                GeometryReader { geometry in
                    BarBalanceGraphBottomRow(geometry: geometry, energy: energy, mode: mode, labels: labels, animateNumericValues: animateNumericValues)
                }
                .frame(height: container.size.height / 2 - 1)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 6,
                    bottomTrailingRadius: 6,
                    topTrailingRadius: 0,
                    style: .continuous
                ))
            }
            .saturation(Settings.baseSaturation)
        }
    }

}
