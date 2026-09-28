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

    var calBurnedNowGraphTotal: Int { DataViewModel.sample.now.graphTotal }
    var activeNowGraphWidthRatio: CGFloat { CGFloat(DataViewModel.sample.now.ratio(of: DataViewModel.sample.now.active)) }
    var passiveNowGraphWidthRatio: CGFloat { CGFloat(DataViewModel.sample.now.ratio(of: DataViewModel.sample.now.resting)) }
    
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

            
        }
        .drawingGroup()
    }
}

struct BarBalanceGraphWatchBottom: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel
    
    let geometry: GeometryProxy
    
    var calBurnedNowGraphTotal: Int { DataViewModel.sample.now.graphTotal }
    
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
            
            let widthConsumed = CGFloat(DataViewModel.sample.now.ratio(of: DataViewModel.sample.now.consumed)) * geometry.size.width
            
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
            
        }
        .drawingGroup()
    }
}
