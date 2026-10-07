import SwiftUI

/// Shows consumed energy against the selected balance total.
struct BarBalanceGraphBottomRow: View {

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
                .overlay {
                    LinearGradient(
                        colors: [scheme == .dark ? .black : .white, AppSettings.getGraphEmptyColor(scheme)],
                        startPoint: scheme == .dark ? .bottom : .top,
                        endPoint: scheme == .dark ? .top : .bottom
                    )
                        .opacity(0.25)
                }
            
            let widthConsumed = CGFloat(energy.ratio(of: energy.consumed)) * geometry.size.width
            
            Rectangle()
                .fill(AppSettings.consumedColor)
                .frame(width: widthConsumed)
                .brightness(level: .primary)
                .overlay {
                    LinearGradient(
                        colors: [scheme == .dark ? .black : .white, AppSettings.burnedColor],
                        startPoint: scheme == .dark ? .bottom : .top,
                        endPoint: scheme == .dark ? .top : .bottom
                    )
                        .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                }
                .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 6, style: .circular))
                .overlay {
                    if labels {
                        ViewThatFits {
                            Text("\(energy.consumed)")
                                .graphLabelStyle(scheme)
                                .contentTransition(animateNumericValues ? .numericText(value: Double(energy.consumed)) : .identity)
                            
                            Color.clear
                                .frame(width: 0, height: 0)
                        }
                        .transaction { transaction in
                            if !animateNumericValues && mode == .now { transaction.animation = .none }
                        }
                    }
                }
            
            if energy.consumed < energy.graphTotal {
                let widthRest = geometry.size.width - widthConsumed
                
                if labels {
                    BarBalanceGraphEndLabel(
                        value: energy.graphTotal - energy.consumed,
                        width: widthRest,
                        animateNumericValues: animateNumericValues
                    )
                    .padding(.leading, widthConsumed)
                }
            }
        }
    }

}
