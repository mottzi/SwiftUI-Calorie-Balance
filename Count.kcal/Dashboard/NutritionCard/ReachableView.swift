import SwiftUI
import WidgetKit

extension Int 
{
    func stringFormat() -> String 
    {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        
        return numberFormatter.string(from: NSNumber(value: self)) ?? String("")
    }
}

enum ViewContext: Hashable
{
    case app
    case widget(WidgetFamily)
}

struct ReachableView: View
{
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.colorScheme) private var scheme: ColorScheme
    @EnvironmentObject private var AppSettings: Settings

    private let gradientOpacityLight: Double = 0.10
    private let gradientOpacityDark: Double = 0.20
    
    private let context: ViewContext
    private var graphHeight: CGFloat = 18.0
    
    private var consumedValue: Int
    private var goalValue: Int
    
    private var percent: Int
    {
        goalValue - consumedValue
    }
    
    private let key: LocalizedStringKey
    private let color:  Color
    
    private let unit: String
    
    init(_  key:         LocalizedStringKey,
         context:        ViewContext = .app,
         consumedValue:  Int,
         goalValue:      Int,
         unit:           String = "g",
         color:          Color = Color("SecondaryTextColor"),
         graphHeight:    CGFloat = 18.0)
    {
        self.context = context
        self.graphHeight = graphHeight
        
        self.consumedValue = consumedValue
        self.goalValue = goalValue
                
        self.key = key
        self.color = color
        
        self.unit = unit
    }
    
    var body: some View
    {
        BarTypeView
    }
    
    var BarTypeView: some View 
    {
        HStack(alignment: .bottom)
        {
            VStack(alignment: .leading, spacing: 3)
            {
                HStack
                {
                    Text(key)
                        .font(.caption)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .padding(.leading, 4)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                        #if !os(watchOS)
                        .foregroundStyle(Color("TextColor"))
                        #endif
                                        
                    let minWidthLeading: [DynamicTypeSize: CGFloat] =
                    [
                        .xSmall: 35,
                        .small: 35,
                        .medium: 35,
                        .large: 35,
                        .xLarge: 35,
                        .xxLarge: 50,
                        .xxxLarge: 65,
                        .accessibility1: 70,
                        .accessibility2: 70,
                        .accessibility3: 70,
                        .accessibility4: 70,
                        .accessibility5: 70,
                    ]
                    
                    let minWidthTrailing: [DynamicTypeSize: CGFloat] =
                    [
                        .xSmall: 35,
                        .small: 35,
                        .medium: 35,
                        .large: 40,
                        .xLarge: 45,
                        .xxLarge: 55,
                        .xxxLarge: 65,
                        .accessibility1: 70,
                        .accessibility2: 80,
                        .accessibility3: 80,
                        .accessibility4: 80,
                        .accessibility5: 80,
                    ]
                    
                    HStack(spacing: 0)
                    {
                        Text("\(consumedValue)")
                            .frame(minWidth: minWidthLeading[dynamicType, default: 30], alignment: .trailing)
                        
                        Text(verbatim: "   / ")
                        
                        Text("\(goalValue) \(String(unit))")
                            .frame(minWidth: minWidthTrailing[dynamicType, default: 40], alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .font(.caption)
                    .fontDesign(.rounded)
                    .fontWeight(.bold)
                    .padding(.trailing, 4)
                    .transaction { $0.animation = .none }
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    #if !os(watchOS)
                    .foregroundStyle(Color("TextColor"))
                    #endif
                }
                
                GeometryReader
                { geometry in
                    NutritionBar(geometry)
                }
                .frame(height: graphHeight)
            }
        }
    }
    
    func getConsumedWidth(_ geometry: GeometryProxy) -> CGFloat
    {
        if goalValue == 0 
        {
            return 0
        }
        
        return max(0, min(geometry.size.width, CGFloat(Double(consumedValue) / Double(goalValue) * geometry.size.width)))
    }
    
    func getConsumedRatio(cap: Double? = nil) -> Double
    {
        if goalValue == 0
        {
            return 0
        }
        
        if cap == nil
        {
            return Double(consumedValue) / Double(goalValue)
        }
        else
        {
            return min(cap!, Double(consumedValue) / Double(goalValue))
        }
    }
    
    func NutritionBar(_ geometry: GeometryProxy) -> some View
    {
        ZStack(alignment: .leading)
        {
            Capsule()
                .fill(AppSettings.getGraphEmptyColor(scheme).brighten(scheme == .light ? 0.15 : -0.05))
                .frame(height: graphHeight)

            Capsule()
                .fill(color.brighten(0.1))
                .saturation(Settings.baseSaturation - 0.2)
                .frame(width: getConsumedWidth(geometry), height: graphHeight)
                .overlay
                {
                    LinearGradient(colors: [scheme == .dark ? .black : .white, color.brighten(0.1)], startPoint: scheme == .dark ? .bottom : .top, endPoint: scheme == .dark ? .top : .bottom)
                        .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                        .clipShape(Capsule())
                }
        }
        .clipShape(Capsule())
    }
}
