import SwiftUI

struct BarBalanceGraphWatchMidnight: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel
    
    var body: some View
    {
        GeometryReader
        { container in
            VStack(spacing: 2)
            {
                GeometryReader
                { geometry in
                    BarBalanceGraphWatchMidnightTop(geometry: geometry)
                }
                .frame(height: container.size.height / 2 - 1)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 6))
                
                GeometryReader
                { geometry in
                    BarBalanceGraphWatchMidnightBottom(geometry: geometry)
                }
                .frame(height: container.size.height / 2 - 1)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 0))
            }
            .saturation(Settings.baseSaturation)
        }
    }
}

struct BarBalanceGraphWatchMidnightTop: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel
    
    let geometry: GeometryProxy

    var burnedActive: Int { AppSettings.dataSource == .apple ? DataViewModel.sample.burnedActive : DataViewModel.sample.burnedActive7 }
    
    var calBurnedMidnightGraphTotal: Int { max(burnedActive + DataViewModel.sample.burnedPassive + DataViewModel.sample.burnedPassiveRemaining, DataViewModel.sample.consumed) }
    
    var activeMidnightGraphWidthRatio: CGFloat { calBurnedMidnightGraphTotal == 0 ? 0.0 : CGFloat(Double(burnedActive) / Double(calBurnedMidnightGraphTotal)) }
    var passiveMidnightGraphWidthRatio: CGFloat { calBurnedMidnightGraphTotal == 0 ? 0.0 : CGFloat(Double(DataViewModel.sample.burnedPassive) / Double(calBurnedMidnightGraphTotal)) }
    var passiveTillMidnightWidthRatio: CGFloat { calBurnedMidnightGraphTotal == 0 ? 0.0 : CGFloat(Double(DataViewModel.sample.burnedPassiveRemaining) / Double(calBurnedMidnightGraphTotal)) }
    
    var body: some View
    {
        ZStack(alignment: .leading)
        {
            Rectangle()
                .fill(AppSettings.getGraphEmptyColor(.dark))
                .frame(width: geometry.size.width)
                .overlay
                {
                    LinearGradient(colors: [.black, AppSettings.getGraphEmptyColor(.dark)], startPoint: .bottom, endPoint: .top)
                        .opacity(0.25)
                }
            
            let widthActive: Double = activeMidnightGraphWidthRatio * geometry.size.width
            
            // active burned
            Rectangle()
                .fill(AppSettings.burnedColor)
                .frame(width: widthActive)
                .brightness(level: .primary)
                .overlay
                {
                    LinearGradient(colors: [.black, AppSettings.burnedColor], startPoint: .bottom, endPoint: .top)
                        .opacity(gradientOpacityDark)
                }
            
            let widthPassive = passiveMidnightGraphWidthRatio * geometry.size.width
            
            // passive burned
            Rectangle()
                .fill(AppSettings.burnedColor)
                .frame(width: widthPassive)
                .brightness(level: .secondary)
                .overlay
                {
                    LinearGradient(colors: [.black, AppSettings.burnedColor], startPoint: .bottom, endPoint: .top)
                        .opacity(gradientOpacityDark)
                }
                .padding(.leading, widthActive)
            
            let widthPassiveTillMidnight = passiveTillMidnightWidthRatio * geometry.size.width
            
            // passive burning till midnight
            Rectangle()
                .fill(AppSettings.burnedColor)
                .frame(width: widthPassiveTillMidnight)
                .brightness(level: .tertiary)
                .overlay
                {
                    LinearGradient(colors: [.black, AppSettings.burnedColor], startPoint: .bottom, endPoint: .top)
                        .opacity(gradientOpacityDark)
                }
                .clipShape(.rect(topTrailingRadius: 6))
                .padding(.leading, widthActive + widthPassive)

            
            let widthRest = geometry.size.width - widthActive - widthPassive - widthPassiveTillMidnight
            
            if(burnedActive + DataViewModel.sample.burnedPassive + DataViewModel.sample.burnedPassiveRemaining < calBurnedMidnightGraphTotal)
            {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: widthRest)
                    .padding(.leading, widthActive + widthPassive + widthPassiveTillMidnight)
            }
        }
        .drawingGroup()
    }
}

struct BarBalanceGraphWatchMidnightBottom: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel
    
    let geometry: GeometryProxy
    
    var burnedActive: Int { AppSettings.dataSource == .apple ? DataViewModel.sample.burnedActive : DataViewModel.sample.burnedActive7 }

    var calBurnedMidnightGraphTotal: Int { max(burnedActive + DataViewModel.sample.burnedPassive + DataViewModel.sample.burnedPassiveRemaining, DataViewModel.sample.consumed) }

    var body: some View
    {
        ZStack(alignment: .leading)
        {
            Rectangle()
                .fill(AppSettings.getGraphEmptyColor(.dark))
                .frame(width: geometry.size.width)
                .overlay
                {
                    LinearGradient(colors: [.blue, AppSettings.getGraphEmptyColor(.dark)], startPoint: .bottom, endPoint: .top)
                        .opacity(0.25)
                }
            
            let widthConsumed = calBurnedMidnightGraphTotal == 0 ? 0.0 : CGFloat(Double(DataViewModel.sample.consumed) / Double(calBurnedMidnightGraphTotal)) * (geometry.size.width)
            
            Rectangle()
                .fill(AppSettings.consumedColor)
                .frame(width: widthConsumed)
                .brightness(level: .primary)
                .overlay
                {
                    LinearGradient(colors: [.black, AppSettings.burnedColor], startPoint: .bottom, endPoint: .top)
                        .opacity(gradientOpacityDark)
                }
                .clipShape(.rect(bottomTrailingRadius: 6))
            
            if (DataViewModel.sample.consumed < calBurnedMidnightGraphTotal)
            {
                let widthRest = geometry.size.width - widthConsumed
                
                ZStack
                {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: widthRest)
                        .padding(.leading, widthConsumed)
                }
            }
        }
        .drawingGroup()
    }
}
