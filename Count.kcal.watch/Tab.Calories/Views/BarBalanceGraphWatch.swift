import SwiftUI

struct BarBalanceGraphWatch: View
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
                    BarBalanceGraphWatchTop(geometry: geometry)
                }
                .frame(height: container.size.height / 2 - 1)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 6))
                
                GeometryReader
                { geometry in
                    BarBalanceGraphWatchBottom(geometry: geometry)
                }
                .frame(height: container.size.height / 2 - 1)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 0))
            }
            .saturation(Settings.baseSaturation)
        }
    }
}

let gradientOpacityLight: Double = 0.10
let gradientOpacityDark: Double = 0.20

struct BarBalanceGraphWatchTop: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel
    
    let geometry: GeometryProxy

    var calBurnedNowGraphTotal: Int { max(DataViewModel.sample.burnedActive + DataViewModel.sample.burnedPassive, DataViewModel.sample.consumed) }
    var activeNowGraphWidthRatio: CGFloat { calBurnedNowGraphTotal == 0 ? 0.0 : CGFloat(Double(DataViewModel.sample.burnedActive) / Double(calBurnedNowGraphTotal)) }
    var passiveNowGraphWidthRatio: CGFloat { calBurnedNowGraphTotal == 0 ? 0.0 : CGFloat(Double(DataViewModel.sample.burnedPassive) / Double(calBurnedNowGraphTotal)) }
    
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
            
            let widthActive: Double = activeNowGraphWidthRatio * geometry.size.width
            
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
            
            let widthPassive = passiveNowGraphWidthRatio * geometry.size.width
            
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
                .clipShape(.rect(topTrailingRadius: 6))
                .padding(.leading, widthActive)

            
//            let widthRest = geometry.size.width - widthActive - widthPassive
            
//            if(DataViewModel.sample.burnedActive + DataViewModel.sample.burnedPassive < calBurnedNowGraphTotal)
//            {
//                ZStack
//                {
//                    Rectangle()
//                        .fill(Color.clear)
//                        .frame(width: widthRest)
//                        .padding(.leading, widthActive + widthPassive)
//                }
//            }
        }
        .drawingGroup()
    }
}

struct BarBalanceGraphWatchBottom: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel
    
    let geometry: GeometryProxy
    
    var calBurnedNowGraphTotal: Int { max(DataViewModel.sample.burnedActive + DataViewModel.sample.burnedPassive, DataViewModel.sample.consumed) }
    
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
            
            let widthConsumed = calBurnedNowGraphTotal == 0 ? 0.0 : CGFloat(Double(DataViewModel.sample.consumed) / Double(calBurnedNowGraphTotal)) * (geometry.size.width)
            
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
            
//            if (DataViewModel.sample.consumed < calBurnedNowGraphTotal)
//            {
//                let widthRest = geometry.size.width - widthConsumed
//                
//                ZStack
//                {
//                    Rectangle()
//                        .fill(Color.clear)
//                        .frame(width: widthRest)
//                        .padding(.leading, widthConsumed)
//                }
//            }
        }
        .drawingGroup()
    }
}
