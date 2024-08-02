import SwiftUI
import Charts

struct WeekBalanceGraph: View 
{
    var DataPoints: [HealthInterface]
    
    @Binding var Pages: [HealthInterface]
    @Binding var selectedPage: HealthInterface?
    @Binding var ignoreChanges: Bool
    
    func findPage(for date: Date) -> HealthInterface?
    {
        Pages.first { $0.sample.date.isSameDay(as: date) }
    }
    
    var maxEnergy: Int
    {
        if let highest = DataPoints.max(by: { abs($0.sample.balanceMidnight) < abs($1.sample.balanceMidnight) })
        {
            return Int(ceil(Double(abs(highest.sample.balanceMidnight))))/* / 1000) * 1000)*/
        }

      return 0
    }

    func isDaySelected(barDay: Date) -> Bool
    {
        if let selectedPage, selectedPage.sample.date.isSameDay(as: barDay)
        {
            return true
        }
        
        return false
    }

    var body: some View
    {
        HStack(spacing: 0)
        {
            ForEach(DataPoints, id: \.self)
            { point in
                VStack(spacing: 6)
                {
                    ZStack
                    {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(Color("TextColor"))
                            .font(.system(size: 18))
                            .opacity(isDaySelected(barDay: point.sample.date) ? 1 : 0)
                
                        Text("\(point.sample.date.workday)")
                            .font(.system(size: 12))
                            .fontDesign(.rounded)
                            .fontWeight(.bold)
                            .foregroundStyle(isDaySelected(barDay: point.sample.date) ? Color("ContrastColor") : Color("TextColor"))
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    }
                    
                    VBarBalanceGraph(balance: point.sample.balanceMidnight, consumed: point.sample.consumed, maxEnergy: maxEnergy, date: point.sample.date)
                        .frame(height: 60)
                }
                .contentShape(.rect)
                .onTapGesture
                {
                    ignoreChanges = true

                    if let page = findPage(for: point.sample.date)
                    {
                        withAnimation(.snappy)
                        {
                            selectedPage = page
                        }
                    }
                }
            }
        }
    }
    
    struct VBarBalanceGraph: View
    {
        @EnvironmentObject private var AppSettings: Settings
        @Environment(\.colorScheme) private var scheme

        let cr = 10.0
        
        let balance: Int
        let consumed: Int
        let maxEnergy: Int
        let date: Date
        
        var barChartRatio: Double
        {
            return min(1, max(-1, Double(balance) / Double(maxEnergy)))
        }
        
        var color: Color
        {
            let color = barChartRatio > 0 ? AppSettings.burnedColor : AppSettings.consumedColor
            let isToday = date.isToday

            if consumed <= 0
            {
                if isToday
                {
                    return color
                }
                else
                {
                    return .secondary
                }
            }
            else
            {
                if isGoalReached() && !isToday
                {
                    return color.brighten(0.3)
                }
                else
                {
                    return color
                }
            }
        }
        
        func barChartHeight(graphHeight: CGFloat) -> CGFloat
        {
            return (graphHeight / 2.0) * abs(barChartRatio)
        }
        
        func isGoalReached() -> Bool
        {
            if AppSettings.weightGoal == .lose
            {
                return balance >= Int(AppSettings.balanceGoal)
            }
            else
            {
                return balance <= -Int(AppSettings.balanceGoal)
            }
        }
        
        var body: some View
        {
            GeometryReader
            { geo in
                ZStack
                {
                    UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: barChartRatio > 0 ? cr : 0, bottomLeading: barChartRatio > 0 ? 0 : cr, bottomTrailing: barChartRatio > 0 ? 0 : cr, topTrailing: barChartRatio > 0 ? cr : 0))
                        .fill(color.brighten(0.1).gradient)
                        .frame(width: geo.size.width * 0.75, height: (geo.size.height / 2.0) * abs(barChartRatio))
                        .overlay
                        {
                            LinearGradient(colors: [scheme == .dark ? .black : .white, color.brighten(0.1)], startPoint: scheme == .dark ? .bottom : .top, endPoint: scheme == .dark ? .top : .bottom)
                                .opacity(scheme == .dark ? gradientOpacityDark : gradientOpacityLight)
                                .clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: barChartRatio > 0 ? cr : 0, bottomLeading: barChartRatio > 0 ? 0 : cr, bottomTrailing: barChartRatio > 0 ? 0 : cr, topTrailing: barChartRatio > 0 ? cr : 0)))
                        }

                        .offset(y: barChartRatio > 0 ? -barChartHeight(graphHeight: geo.size.height) / 2 - 1: barChartHeight(graphHeight: geo.size.height) / 2 + 1)
                    
                    Rectangle()
                        .frame(width: geo.size.width, height: 2)
                        .foregroundStyle(Color("TextColor").opacity(0.7))
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .overlay
                {
                    Text("\(abs(balance))")
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .font(.caption)
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("TextColor"))
                        .offset(y: balance > 0 ? 14 : -14)
                }
//                .opacity(c)
            }
        }
    }
}

let d = [
    HealthInterface(HealthData.example(for: .now))
]

//#Preview
//{
//    WeekBalanceGraph(DataPoints: d)
//}

#Preview { PreviewPager }
