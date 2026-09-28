import SwiftUI

/// Shows projected burned and consumed energy in two horizontal bars.
struct BarBalanceGraphMidnight: View {

    @Environment(\.colorScheme) private var scheme: ColorScheme

    @EnvironmentObject private var AppSettings: Settings

    var context: ViewContext = .app

    /// The snapshot projection used for every segment and label.
    let energy: EnergyBalance

    let consumedColor: Color
    let burnedColor: Color
        
    var body: some View {
        GeometryReader { container in
            VStack(spacing: scheme == .light ? 1 : 2) {
                GeometryReader { geometry in
                    bottomGraphTopRow(geometry, context)
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
                    bottomGraphBottomRow(geometry, context)
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

extension BarBalanceGraphMidnight {

    func bottomGraphTopRow(_ geometry: GeometryProxy, _ context: ViewContext) -> some View {
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

            let widthActive: Double = activeGraphRatio * geometry.size.width
            
            // active burned
            Rectangle()
                .fill(burnedColor)
                .frame(width: widthActive)
                .brightness(level: .primary)
                .overlay {
                    LinearGradient(
                        colors: [scheme == .dark ? .black : .white, AppSettings.burnedColor],
                        startPoint: scheme == .dark ? .bottom : .top,
                        endPoint: scheme == .dark ? .top : .bottom
                    )
                        .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                }
                .overlay {
                    ViewThatFits {
                        Text("\(energy.active)").graphLabelStyle(scheme)
                        
                        Color.clear.frame(width: 0, height: 0)
                    }
                }
            
            let widthPassive = passiveGraphRatio * geometry.size.width
            
            // passive burned
            Rectangle()
                .fill(burnedColor)
                .frame(width: widthPassive)
                .brightness(level: .secondary)
                .overlay {
                    LinearGradient(
                        colors: [scheme == .dark ? .black : .white, AppSettings.burnedColor],
                        startPoint: scheme == .dark ? .bottom : .top,
                        endPoint: scheme == .dark ? .top : .bottom
                    )
                        .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                }
                .overlay {
                    ViewThatFits {
                        Text("\(energy.resting)").graphLabelStyle(scheme)

                        Color.clear.frame(width: 0, height: 0)
                    }
                }
                .padding(.leading, widthActive)
            
            let widthPassiveTillMidnight = passiveRemainingRatio * geometry.size.width
            
            // passive burning till midnight
            Rectangle()
                .fill(burnedColor)
                .frame(width: widthPassiveTillMidnight)
                .brightness(level: .tertiary)
                .overlay {
                    LinearGradient(
                        colors: [scheme == .dark ? .black : .white, AppSettings.burnedColor],
                        startPoint: scheme == .dark ? .bottom : .top,
                        endPoint: scheme == .dark ? .top : .bottom
                    )
                        .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                }
                .clipShape(UnevenRoundedRectangle(topTrailingRadius: 6, style: .circular))
                .overlay {
                    ViewThatFits {
                        Text("\(energy.restingRemaining)").graphLabelStyle(scheme)
                        
                        Color.clear.frame(width: 0, height: 0)
                    }
                }
                .padding(.leading, widthActive + widthPassive)
            
            let widthRest = geometry.size.width - widthActive - widthPassive - widthPassiveTillMidnight
            
            if energy.burned < energy.graphTotal {
                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: widthRest)
                        .padding(.leading, widthActive + widthPassive + widthPassiveTillMidnight)
                    
                    if widthRest <= 25 {
                        Text("\(energy.graphTotal - energy.burned)")
                            .graphLabelStyle(scheme)
                            .padding(.leading, widthActive + widthPassive + widthPassiveTillMidnight - 18)
                    } else {
                        Text("\(energy.graphTotal - energy.burned)")
                            .graphLabelStyle(scheme)
                            .padding(.leading, widthActive + widthPassive + widthPassiveTillMidnight)
                    }
                }
            }
        }
        .drawingGroup()
//        .geometryGroup()
//        .compositingGroup()
    }
    
    func bottomGraphBottomRow(_ geometry: GeometryProxy, _ context: ViewContext) -> some View {
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
                .fill(consumedColor)
                .frame(width: widthConsumed)
                .overlay {
                    LinearGradient(
                        colors: [scheme == .dark ? .black : .white, AppSettings.burnedColor],
                        startPoint: scheme == .dark ? .bottom : .top,
                        endPoint: scheme == .dark ? .top : .bottom
                    )
                        .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                }
                .brightness(level: .primary)
                .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 6, style: .circular))
                .overlay {
                    ViewThatFits {
                        Text("\(energy.consumed)").graphLabelStyle(scheme)
                        
                        Color.clear.frame(width: 0, height: 0)
                    }
                }
            
            if (energy.consumed < energy.graphTotal) {
                let widthRest = geometry.size.width - widthConsumed
                
                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: widthRest)
                        .padding(.leading, widthConsumed)

                    Text("\(energy.graphTotal - energy.consumed)")
                        .graphLabelStyle(scheme)
                        .padding(.leading, widthRest <= 25 ? widthConsumed - 18 : widthConsumed)
                }
            }
        }
        .drawingGroup()
//        .geometryGroup()
//        .compositingGroup()
    }

    var activeGraphRatio: CGFloat { CGFloat(energy.ratio(of: energy.active)) }
    var passiveGraphRatio: CGFloat { CGFloat(energy.ratio(of: energy.resting)) }
    var passiveRemainingRatio: CGFloat { CGFloat(energy.ratio(of: energy.restingRemaining)) }

}
