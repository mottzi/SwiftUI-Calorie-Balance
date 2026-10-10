import SwiftUI

let gradientOpacityLight: Double = 0.10
let gradientOpacityDark: Double = 0.20

/// Shows recorded burned energy and any end-of-day projection.
struct BarBalanceGraphTopRow: View {

    @Environment(\.colorScheme) private var scheme: ColorScheme

    @EnvironmentObject private var AppSettings: Settings

    let geometry: GeometryProxy
    let energy: EnergyBalance
    let mode: GraphMode
    let labels: Bool
    let animateNumericValues: Bool

    var body: some View {
        if animateNumericValues {
            rowContent.compositingGroup()
        } else {
            rowContent.drawingGroup()
        }
    }

    private var rowContent: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(AppSettings.getGraphEmptyColor(scheme).opacity(scheme == .light ? 0.4 : 1))
                .frame(width: geometry.size.width)
            
            let widthActive = CGFloat(energy.ratio(of: energy.active)) * geometry.size.width
            
            // active burned
            Rectangle()
                .fill(AppSettings.burnedColor.gradient)
                .brightness(level: .primary, to: .circlegraphMidnight)
                .graphColorAppearance()
                .frame(width: widthActive)
                .overlay {
                    if labels {
                        ViewThatFits {
                            Text("\(energy.active)")
                                .graphLabelStyle(scheme)
                                .contentTransition(animateNumericValues ? .numericText(value: Double(energy.active)) : .identity)
                            
                            Color.clear.frame(width: 0, height: 0)
                        }
                        .transaction { transaction in
                            if !animateNumericValues && mode == .now { transaction.animation = .none }
                        }
                    }
                }

            
            let widthPassive = CGFloat(energy.ratio(of: energy.resting)) * geometry.size.width
            
            // passive burned
            Rectangle()
                .fill(AppSettings.burnedColor.gradient)
                .brightness(level: .secondary, to: .circlegraphMidnight)
                .graphColorAppearance()
                .frame(width: widthPassive)
                .clipShape(UnevenRoundedRectangle(topTrailingRadius: mode == .now ? 6 : 0, style: .circular))
                .overlay {
                    if labels {
                        ViewThatFits {
                            Text("\(energy.resting)")
                                .graphLabelStyle(scheme)
                                .contentTransition(animateNumericValues ? .numericText(value: Double(energy.resting)) : .identity)

                            Color.clear
                                .frame(width: 0, height: 0)
                        }
                        .transaction { transaction in
                            if !animateNumericValues && mode == .now { transaction.animation = .none }
                        }
                    }
                }
                .padding(.leading, widthActive)

            
            let widthProjected = mode == .midnight
                ? CGFloat(energy.ratio(of: energy.restingRemaining)) * geometry.size.width
                : 0

            // Keep the projection in the row so its width can animate from and to zero.
            Rectangle()
                .fill(AppSettings.burnedColor.gradient)
                .brightness(level: .tertiary, to: .circlegraphMidnight)
                .graphColorAppearance()
                .frame(width: widthProjected)
                .clipShape(UnevenRoundedRectangle(topTrailingRadius: 6, style: .circular))
                .overlay {
                    if labels && energy.restingRemaining > 0 {
                        BarBalanceGraphEndLabel(
                            value: energy.restingRemaining,
                            width: widthProjected,
                            animateNumericValues: animateNumericValues
                        )
                    }
                }
                .padding(.leading, widthActive + widthPassive)
                .opacity(mode == .midnight ? 1 : 0)

            let widthRest = geometry.size.width - widthActive - widthPassive - widthProjected
            
            if energy.burned < energy.graphTotal {
                if labels {
                    BarBalanceGraphEndLabel(
                        value: energy.graphTotal - energy.burned,
                        width: widthRest,
                        animateNumericValues: animateNumericValues
                    )
                    .padding(.leading, widthActive + widthPassive + widthProjected)
                }
            }
        }
    }

}

#Preview("Trailing values") {
    VStack(spacing: 20) {
        ForEach([ColorScheme.dark, .light], id: \.self) { scheme in
            VStack(spacing: 12) {
                ForEach([
                    EnergyBalance(active: 346, resting: 1_595, restingRemaining: 120, consumed: 1_769),
                    EnergyBalance(active: 650, resting: 1_660, consumed: 2_490),
                    EnergyBalance(active: 346, resting: 1_595, restingRemaining: 5, consumed: 1_769),
                    EnergyBalance(active: 650, resting: 1_660, consumed: 2_315)
                ].enumerated().map { $0 }, id: \.offset) { _, energy in
                    VStack(spacing: 2) {
                        GeometryReader { geometry in
                            BarBalanceGraphTopRow(geometry: geometry, energy: energy, mode: .midnight, labels: true, animateNumericValues: false)
                        }
                        GeometryReader { geometry in
                            BarBalanceGraphBottomRow(geometry: geometry, energy: energy, mode: .midnight, labels: true, animateNumericValues: false)
                        }
                    }
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(16)
            .background(scheme == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, scheme)
        }
    }
    .environmentObject(Settings.shared)
    .padding(16)
}
