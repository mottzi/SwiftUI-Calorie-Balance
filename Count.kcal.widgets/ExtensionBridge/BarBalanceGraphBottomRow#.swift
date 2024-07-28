import SwiftUI

struct BarBalanceGraphBottomRow: View
{
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel
    
    let geometry: GeometryProxy
    let context: ViewContext
    
    var calBurnedNowGraphTotal: Int { max(DataViewModel.sample.burnedActive + DataViewModel.sample.burnedPassive, DataViewModel.sample.consumed) }
    
    var body: some View
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
            
            let widthConsumed = calBurnedNowGraphTotal == 0 ? 0.0 : CGFloat(Double(DataViewModel.sample.consumed) / Double(calBurnedNowGraphTotal)) * (geometry.size.width)
            
            Rectangle()
                .fill(AppSettings.consumedColor)
                .frame(width: widthConsumed)
                .brightness(level: .primary)
                .overlay
                {
                    LinearGradient(colors: [scheme == .dark ? .black : .white, AppSettings.burnedColor], startPoint: scheme == .dark ? .bottom : .top, endPoint: scheme == .dark ? .top : .bottom)
                        .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                }
                .cornerRadius(6, corners: .bottomRight)
                .overlay
                {
                    ViewThatFits
                    {
                        Text("\(DataViewModel.sample.consumed)").graphLabelStyle(scheme)
                        
                        Color.clear
                            .frame(width: 0, height: 0)
                    }
                    .transaction { transaction in transaction.animation = .none }
                }
            
            if (DataViewModel.sample.consumed < calBurnedNowGraphTotal)
            {
                let widthRest = geometry.size.width - widthConsumed
                
                ZStack
                {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: widthRest)
                        .padding(.leading, widthConsumed)
                    
                    if widthRest <= 25
                    {
                        Text("\(calBurnedNowGraphTotal - DataViewModel.sample.consumed)")
                            .graphLabelStyle(scheme)
                            .padding(.leading, widthConsumed - 18)
                    }
                    else
                    {
                        Text("\(calBurnedNowGraphTotal - DataViewModel.sample.consumed)")
                            .graphLabelStyle(scheme)
                            .padding(.leading, widthConsumed)
                    }
                }
            }
        }
        .drawingGroup()
//        .geometryGroup()
//        .compositingGroup()
    }
}
