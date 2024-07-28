import SwiftUI

struct BarBalanceGraphMidnight: View
{
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var AppSettings: Settings

    var context: ViewContext = .app

    let burnedActive: Int
    let burnedPassive: Int
    let burnedPassive7: Int
    let consumed: Int

    let consumedColor: Color
    let burnedColor: Color
        
    var balanceMidnight: Int { burnedPassive + burnedPassiveRemaining + burnedActive - consumed }
    var burnedPassiveRemaining: Int { max(burnedPassive7 - burnedPassive, 0) }
    var calBurnedMidnightGraphTotal: Int { max(burnedActive + burnedPassive + burnedPassiveRemaining, consumed) }
    
    var activeMidnightGraphWidthRatio: CGFloat { calBurnedMidnightGraphTotal == 0 ? 0.0 : CGFloat(Double(burnedActive) / Double(calBurnedMidnightGraphTotal)) }
    var passiveMidnightGraphWidthRatio: CGFloat { calBurnedMidnightGraphTotal == 0 ? 0.0 : CGFloat(Double(burnedPassive) / Double(calBurnedMidnightGraphTotal)) }
    var passiveTillMidnightWidthRatio: CGFloat { calBurnedMidnightGraphTotal == 0 ? 0.0 : CGFloat(Double(self.burnedPassiveRemaining) / Double(calBurnedMidnightGraphTotal)) }

    var body: some View
    {
        GeometryReader
        { container in
            VStack(spacing: scheme == .light ? 1 : 2)
            {
                GeometryReader
                { geometry in
                    bottomGraphTopRow(geometry, context)
                }
                .frame(height: container.size.height / 2 - 1)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 6, style: .continuous))
                    
                GeometryReader
                { geometry in
                    bottomGraphBottomRow(geometry, context)
                }
                .frame(height: container.size.height / 2 - 1)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 0, style: .continuous))
            }
            .saturation(Settings.baseSaturation)
        }
    }
    
    func bottomGraphTopRow(_ geometry: GeometryProxy, _ context: ViewContext) -> some View
    {
        ZStack(alignment: .leading)
        {
            Rectangle()
                .fill(AppSettings.getGraphEmptyColor(scheme).opacity(scheme == .light ? 0.4 : 1))
                .frame(width: geometry.size.width)
                .overlay
                {
                    LinearGradient(colors: [scheme == .dark ? .black : .white, AppSettings.getGraphEmptyColor(scheme)], startPoint: scheme == .dark ? .bottom : .top, endPoint: scheme == .dark ? .top : .bottom)
                        .opacity(0.25)
                }

            let widthActive: Double = activeMidnightGraphWidthRatio * geometry.size.width
            
            // active burned
            Rectangle()
                .fill(burnedColor)
                .frame(width: widthActive)
                .brightness(level: .primary)
                .overlay
                {
                    LinearGradient(colors: [scheme == .dark ? .black : .white, AppSettings.burnedColor], startPoint: scheme == .dark ? .bottom : .top, endPoint: scheme == .dark ? .top : .bottom)
                        .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                }
                .overlay
                {
                    ViewThatFits
                    {
                        Text("\(burnedActive)").graphLabelStyle(scheme)
                        
                        Color.clear.frame(width: 0, height: 0)
                    }
                }
            
            let widthPassive = passiveMidnightGraphWidthRatio * geometry.size.width
            
            // passive burned
            Rectangle()
                .fill(burnedColor)
                .frame(width: widthPassive)
                .brightness(level: .secondary)
                .overlay
                {
                    LinearGradient(colors: [scheme == .dark ? .black : .white, AppSettings.burnedColor], startPoint: scheme == .dark ? .bottom : .top, endPoint: scheme == .dark ? .top : .bottom)
                        .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                }
                .overlay
                {
                    ViewThatFits
                    {
                        Text("\(burnedPassive)").graphLabelStyle(scheme)

                        Color.clear.frame(width: 0, height: 0)
                    }
                }
                .padding(.leading, widthActive)
            
            let widthPassiveTillMidnight = passiveTillMidnightWidthRatio * geometry.size.width
            
            // passive burning till midnight
            Rectangle()
                .fill(burnedColor)
                .frame(width: widthPassiveTillMidnight)
                .brightness(level: .tertiary)
                .overlay
                {
                    LinearGradient(colors: [scheme == .dark ? .black : .white, AppSettings.burnedColor], startPoint: scheme == .dark ? .bottom : .top, endPoint: scheme == .dark ? .top : .bottom)
                        .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                }
                .cornerRadius(6, corners: .topRight)
                .overlay
                {
                    ViewThatFits
                    {
                        Text("\(burnedPassiveRemaining)").graphLabelStyle(scheme)
                        
                        Color.clear.frame(width: 0, height: 0)
                    }
                }
                .padding(.leading, widthActive + widthPassive)
            
            let widthRest = geometry.size.width - widthActive - widthPassive - widthPassiveTillMidnight
            
            if(burnedActive + burnedPassive + burnedPassiveRemaining < calBurnedMidnightGraphTotal)
            {
                ZStack
                {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: widthRest)
                        .padding(.leading, widthActive + widthPassive + widthPassiveTillMidnight)
                    
                    if widthRest <= 25
                    {
                        Text("\(calBurnedMidnightGraphTotal - (burnedActive + burnedPassive + burnedPassiveRemaining))")
                            .graphLabelStyle(scheme)
                            .padding(.leading, widthActive + widthPassive + widthPassiveTillMidnight - 18)
                    }
                    else
                    {
                        Text("\(calBurnedMidnightGraphTotal - (burnedActive + burnedPassive + burnedPassiveRemaining))")
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
    
    func bottomGraphBottomRow(_ geometry: GeometryProxy, _ context: ViewContext) -> some View
    {
        ZStack(alignment: .leading)
        {
            Rectangle()
                .fill(AppSettings.getGraphEmptyColor(scheme).opacity(scheme == .light ? 0.4 : 1))
                .frame(width: geometry.size.width)
                .overlay
                {
                    LinearGradient(colors: [scheme == .dark ? .black : .white, AppSettings.getGraphEmptyColor(scheme)], startPoint: scheme == .dark ? .bottom : .top, endPoint: scheme == .dark ? .top : .bottom)
                        .opacity(0.25)
                }
            
            let widthConsumed = calBurnedMidnightGraphTotal == 0 ? 0.0 : CGFloat(Double(consumed) / Double(calBurnedMidnightGraphTotal)) * (geometry.size.width)
            
            Rectangle()
                .fill(consumedColor)
                .frame(width: widthConsumed)
                .overlay
                {
                    LinearGradient(colors: [scheme == .dark ? .black : .white, AppSettings.burnedColor], startPoint: scheme == .dark ? .bottom : .top, endPoint: scheme == .dark ? .top : .bottom)
                        .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                }
                .brightness(level: .primary)
                .cornerRadius(6, corners: .bottomRight)
                .overlay
                {
                    ViewThatFits
                    {
                        Text("\(consumed)").graphLabelStyle(scheme)
                        
                        Color.clear.frame(width: 0, height: 0)
                    }
                }
            
            if (consumed < calBurnedMidnightGraphTotal)
            {
                let widthRest = geometry.size.width - widthConsumed
                
                ZStack
                {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: widthRest)
                        .padding(.leading, widthConsumed)

                    Text("\(calBurnedMidnightGraphTotal - consumed)")
                        .graphLabelStyle(scheme)
                        .padding(.leading, widthRest <= 25 ? widthConsumed - 18 : widthConsumed)
                }
            }
        }
        .drawingGroup()
//        .geometryGroup()
//        .compositingGroup()
    }
}
