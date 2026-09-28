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

    var burnedActive: Int { DataViewModel.sample.burnedActiveMidnight }
    
    var calBurnedMidnightGraphTotal: Int { DataViewModel.sample.midnight.graphTotal }
    
    var activeMidnightGraphWidthRatio: CGFloat { CGFloat(DataViewModel.sample.midnight.ratio(of: burnedActive)) }
    var passiveMidnightGraphWidthRatio: CGFloat { CGFloat(DataViewModel.sample.midnight.ratio(of: DataViewModel.sample.midnight.resting)) }
    var passiveTillMidnightWidthRatio: CGFloat { CGFloat(DataViewModel.sample.midnight.ratio(of: DataViewModel.sample.midnight.restingRemaining)) }
    
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
            
            if(DataViewModel.sample.midnight.burned < calBurnedMidnightGraphTotal)
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
    
    var burnedActive: Int { DataViewModel.sample.burnedActiveMidnight }

    var calBurnedMidnightGraphTotal: Int { DataViewModel.sample.midnight.graphTotal }

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
            
            let widthConsumed = CGFloat(DataViewModel.sample.midnight.ratio(of: DataViewModel.sample.midnight.consumed)) * geometry.size.width
            
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
