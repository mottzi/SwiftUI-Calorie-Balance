import SwiftUI
import Charts

struct WeeklyChart: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(WeightDataViewModel.self) private var WeightViewModel

    var body: some View
    {
        if WeightViewModel.dataLoaded
        {
            Chart
            {
                // average line horizontal
                RuleMark(y: .value("Value", WeightViewModel.weightAvg7))
                    .foregroundStyle(getTrendColor(.weekly).opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                
                // today highlight background
                RectangleMark(xStart: .value("Date", WeightViewModel.WeeklyWeightData.last!.date.tomorrow), xEnd: .value("Date", WeightViewModel.WeeklyWeightData.last!.date))
                    .foregroundStyle(Color("SecondaryTextColor").opacity(0.1))
                
                let gradient = LinearGradient(stops: [.init(color: getTrendColor(.weekly), location: 0.5), .init(color: Color.clear, location: 1.5)], startPoint: .trailing, endPoint: .leading)
                
                ForEach(Array(WeightViewModel.validData(.weekly).enumerated()), id: \.element.id)
                { (index, item) in
                    // data point label
                    BarMark(
                        x: .value("Date", item.date, unit: .weekday),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(Color.clear)
                    .annotation(spacing: 8)
                    {
                        Text(verbatim: String(format: "%.1f", item.weightAvg!))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color("SecondaryTextColor1").opacity((index == WeightViewModel.validData(.weekly).count - 1) ? 1 : 0.6))
                    }
                    
                    LineMark(
                        x: .value("Date", item.date, unit: .weekday),
                        y: .value("Value", item.weightAvg!)
                    )
                    // data point symbol
                    .symbol
                    {
                        CircleChartSymbol(index: index, page: .weekly)
                            .environment(WeightViewModel)
                            .environmentObject(AppSettings)
                    }
                    .foregroundStyle(gradient)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 8))
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .brightness(level: .primary)
            .saturation(Settings.baseSaturation)
            .padding(.top, 22)
            //.padding(.trailing, 15)
            .padding(.horizontal, 13)

            .chartYScale(domain: WeightViewModel.getYRange(.weekly))
            .chartYAxis
            {
                AxisMarks(values: WeightViewModel.createYRangeArray(.weekly))
                {
                    // AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2], dashPhase: 0))
                    AxisValueLabel()
                }
                
                AxisMarks(values: [WeightViewModel.getYTopRange(.weekly), WeightViewModel.getYBottomRange(.weekly)])
                {
                    AxisGridLine()
                }
                
            }
            .chartXScale(domain: WeightViewModel.WeeklyWeightData.first!.date ...  WeightViewModel.WeeklyWeightData.last!.date.tomorrow)
            .chartXAxis
            {
                AxisMarks(values: .stride(by: .day))
                { day in
                    if day.index != 0 && day.index != day.count - 1
                    {
                        AxisGridLine()
                    }
                    else
                    {
                        AxisGridLine(stroke: .init(lineWidth: 0.5))
                    }
                    
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
        }
    }
    
    func getTrendColor(_ page: WeightPage) -> Color
    {
        if page == .weekly
        {
            if !WeightViewModel.dataLoaded
            {
                return Color(white: 0.22)
            }
            
            guard let lastWeight = WeightViewModel.lastWeightValue(.weekly)/*,
                  let firstWeight = WeightViewModel.firstWeightValue(.weekly)*/
            else
            {
                return Color(white: 0.22)
            }
            
            if lastWeight > WeightViewModel.weightAvg7
            {
                return AppSettings.consumedColor
            }
            else if lastWeight < WeightViewModel.weightAvg7
            {
                return AppSettings.burnedColor
            }
        }
        else if page == .monthly
        {
//            print("getting trend color")
            
            if !WeightViewModel.dataLoaded
            {
                return Color(white: 0.22)
            }
            
            guard let lastWeight = WeightViewModel.lastWeightValue(.monthly)/*,
                  let firstWeight = WeightViewModel.firstWeightValue(.monthly)*/
            else
            {
                return Color(white: 0.22)
            }
            
//            print("lastWeight: \(lastWeight), avgWeight: \(WeightViewModel.weightAvg30)")
            
            if lastWeight > WeightViewModel.weightAvg30
            {
                return AppSettings.consumedColor
            }
            else if lastWeight < WeightViewModel.weightAvg30
            {
                return AppSettings.burnedColor
            }
        }
        
        return Color(white: 0.22)
    }
}

#Preview
{
    NavigationView
    {
        ZStack
        {
            Settings.shared.AppBackground.ignoresSafeArea(.all)
            
            Pager(lb: 6, tb: 1)
                .environmentObject(Settings.shared)
                .environment(WeightDataViewModel())
        }
    }
}
