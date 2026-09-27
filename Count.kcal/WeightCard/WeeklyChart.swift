import SwiftUI
import Charts

struct WeeklyChart: View {
    @EnvironmentObject private var AppSettings: Settings

    @Environment(WeightDataViewModel.self) private var WeightViewModel

    var body: some View {
        if WeightViewModel.dataLoaded {
            Chart {
                // average line horizontal
                RuleMark(y: .value("Value", WeightViewModel.weightAvg7))
                    .foregroundStyle(trendColor.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                
                // today highlight background
                RectangleMark(
                    xStart: .value("Date", WeightViewModel.WeeklyWeightData.last!.date.tomorrow),
                    xEnd: .value("Date", WeightViewModel.WeeklyWeightData.last!.date)
                )
                    .foregroundStyle(Color("SecondaryTextColor").opacity(0.1))
                
                let gradient = LinearGradient(
                    stops: [.init(color: trendColor, location: 0.5), .init(color: Color.clear, location: 1.5)],
                    startPoint: .trailing,
                    endPoint: .leading
                )
                
                let validData = WeightViewModel.validData(.weekly)

                ForEach(Array(validData.enumerated()), id: \.element.id) { (index, item) in
                    // data point label
                    BarMark(
                        x: .value("Date", item.date, unit: .weekday),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(Color.clear)
                    .annotation(spacing: 8) {
                        Text(verbatim: String(format: "%.1f", item.weightAvg!))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color("SecondaryTextColor1").opacity((index == validData.count - 1) ? 1 : 0.6))
                    }
                    
                    LineMark(
                        x: .value("Date", item.date, unit: .weekday),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(gradient)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 8))

                    PointMark(
                        x: .value("Date", item.date, unit: .weekday),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(Color(index == validData.count - 1 ? "SecondaryTextColor1" : "SecondaryTextColor"))
                    .symbolSize(index == validData.count - 1 ? 113 : 50)

                    PointMark(
                        x: .value("Date", item.date, unit: .weekday),
                        y: .value("Value", item.weightAvg!)
                    )
                    .foregroundStyle(AppSettings.CardBackground)
                    .symbolSize(index == validData.count - 1 ? 28 : 13)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .brightness(level: .primary)
            .saturation(Settings.baseSaturation)
            .padding(.top, 22)
            //.padding(.trailing, 15)
            .padding(.horizontal, 13)

            .chartYScale(domain: WeightViewModel.getYRange(.weekly))
            .chartYAxis {
                AxisMarks(values: WeightViewModel.createYRangeArray(.weekly)) {
                    // AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2], dashPhase: 0))
                    AxisValueLabel()
                }
                
                AxisMarks(values: [WeightViewModel.getYTopRange(.weekly), WeightViewModel.getYBottomRange(.weekly)]) {
                    AxisGridLine()
                }
                
            }
            .chartXScale(domain: WeightViewModel.WeeklyWeightData.first!.date ...  WeightViewModel.WeeklyWeightData.last!.date.tomorrow)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { day in
                    if day.index != 0 && day.index != day.count - 1 {
                        AxisGridLine()
                    } else {
                        AxisGridLine(stroke: .init(lineWidth: 0.5))
                    }
                    
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
        }
    }
    
    /// Uses the period trend to select the existing chart color.
    private var trendColor: Color {
        switch WeightViewModel.trend(for: .weekly) {
            case .orderedAscending: AppSettings.burnedColor
            case .orderedDescending: AppSettings.consumedColor
            default: Color(white: 0.22)
        }
    }
}

#Preview {
    NavigationView {
        ZStack {
            Settings.shared.AppBackground.ignoresSafeArea(.all)
            
            Pager(lb: 6, tb: 1)
                .environmentObject(Settings.shared)
                .environment(WeightDataViewModel())
        }
    }
}
