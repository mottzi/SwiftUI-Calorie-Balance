import SwiftUI
import Charts

struct MonthlyChart: View 
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(WeightDataViewModel.self) private var WeightViewModel

    var body: some View
    {
        if WeightViewModel.dataLoaded
        {
            Chart
            {
                RuleMark(y: .value("Value", WeightViewModel.weightAvg30))
                    .foregroundStyle(getTrendColor(.monthly).opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                
                RectangleMark(
                    xStart: .value("Date", WeightViewModel.WeightData.last!.date.lastMonday),
                    xEnd: .value("Date", WeightViewModel.WeightData.last!.date.nextSunday.tomorrow)
                )
                .foregroundStyle(Color("SecondaryTextColor").opacity(0.1))
                
                let gradient = LinearGradient(stops: [.init(color: getTrendColor(.monthly), location: 0.5), .init(color: Color.clear, location: 1.5)], startPoint: .trailing, endPoint: .leading)
                
                ForEach(Array(WeightViewModel.validData(.monthly).enumerated()), id: \.element.id)
                { (index, item) in
                    LineMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Value", item.weightAvg!)
                    )
                    .symbol 
                    {
                        CircleChartSymbol(index: index, page: .monthly)
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
//            .padding(.trailing, 15)
            .padding(.horizontal, 12)

            .chartYScale(domain: WeightViewModel.getYRange(.monthly))
            .chartYAxis { AxisMarks(position: .trailing, values: WeightViewModel.createYRangeArray(.monthly)) }
            .chartXScale(domain: WeightViewModel.WeightData.first!.date ... WeightViewModel.WeightData.last!.date.nextSunday.tomorrow)
            .chartXAxis
            {
                AxisMarks(values: .stride(by: .day, count: 7))
                { date in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day(.twoDigits) , centered: false)
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
