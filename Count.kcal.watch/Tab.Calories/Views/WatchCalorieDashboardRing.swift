import SwiftUI

/// Full-width rings shared by the personal dashboard and shared calorie cards.
struct WatchCalorieDashboardRing: View {
    let energy: EnergyBalance
    let palette: CalorieGraphPalette
    var cutout = 0.28

    var body: some View {
        GeometryReader { geometry in
            let diameter = geometry.size.width
            CalorieCircleGraph(
                energy: energy,
                configuration: .init(
                    lineWidth: diameter * 0.08,
                    ringSpacing: diameter * 0.02,
                    openAngle: .degrees(cutout * 360)
                ),
                palette: palette
            )
            .frame(width: diameter, height: diameter)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
