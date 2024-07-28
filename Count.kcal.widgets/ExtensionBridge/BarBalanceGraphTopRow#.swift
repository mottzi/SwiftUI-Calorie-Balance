import SwiftUI

let gradientOpacityLight: Double = 0.10
let gradientOpacityDark: Double = 0.20

struct BarBalanceGraphTopRow: View
{
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel
    
    let geometry: GeometryProxy
    let context: ViewContext

    var calBurnedNowGraphTotal: Int { max(DataViewModel.sample.burnedActive + DataViewModel.sample.burnedPassive, DataViewModel.sample.consumed) }
    var activeNowGraphWidthRatio: CGFloat { calBurnedNowGraphTotal == 0 ? 0.0 : CGFloat(Double(DataViewModel.sample.burnedActive) / Double(calBurnedNowGraphTotal)) }
    var passiveNowGraphWidthRatio: CGFloat { calBurnedNowGraphTotal == 0 ? 0.0 : CGFloat(Double(DataViewModel.sample.burnedPassive) / Double(calBurnedNowGraphTotal)) }
    
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
            
            let widthActive: Double = activeNowGraphWidthRatio * geometry.size.width
            
            // active burned
            Rectangle()
                .fill(AppSettings.burnedColor)
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
                        Text("\(DataViewModel.sample.burnedActive)").graphLabelStyle(scheme)
                        
                        Color.clear.frame(width: 0, height: 0)
                    }
                    .transaction { transaction in transaction.animation = .none }
                }

            
            let widthPassive = passiveNowGraphWidthRatio * geometry.size.width
            
            // passive burned
            Rectangle()
                .fill(AppSettings.burnedColor)
                .frame(width: widthPassive)
                .brightness(level: .secondary)
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
                        Text("\(DataViewModel.sample.burnedPassive)").graphLabelStyle(scheme)

                        Color.clear
                            .frame(width: 0, height: 0)
                    }
                    .transaction { transaction in transaction.animation = .none }
                }
                .padding(.leading, widthActive)

            
            let widthRest = geometry.size.width - widthActive - widthPassive
            
            if(DataViewModel.sample.burnedActive + DataViewModel.sample.burnedPassive < calBurnedNowGraphTotal)
            {
                ZStack
                {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: widthRest)
                        .padding(.leading, widthActive + widthPassive)
                    
                    if widthRest <= 25
                    {
                        Text("\(calBurnedNowGraphTotal - (DataViewModel.sample.burnedActive + DataViewModel.sample.burnedPassive))")
                            .graphLabelStyle(scheme)
                            .padding(.leading, widthActive + widthPassive - 18)
                    }
                    else
                    {
                        Text("\(calBurnedNowGraphTotal - (DataViewModel.sample.burnedActive + DataViewModel.sample.burnedPassive))")
                            .graphLabelStyle(scheme)
                            .padding(.leading, widthActive + widthPassive)
                    }
                }
            }
        }
        .drawingGroup()
//        .geometryGroup()
//        .compositingGroup()
    }
}

extension View
{
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View
    {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape
{
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path
    {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        
        return Path(path.cgPath)
    }
}
