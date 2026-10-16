import SwiftUI
import Charts

/// Only the weight trend is useful at this scale; controls and totals add noise.
struct DashboardPreviewProgress: View {
    @EnvironmentObject private var settings: Settings
    @Environment(WeightHistory.self) private var weights

    var body: some View {
        Chart(weights.validData(.weekly)) { item in
            if let weight = item.weightAvg {
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Weight", weight)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 8, lineCap: .round))
                .foregroundStyle(Color("SecondaryTextColor"))

                if item.id == weights.weeklyAverages.last?.id {
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Weight", weight)
                    )
                    .symbolSize(80)
                    .foregroundStyle(Color("TextColor"))
                }
            }
        }
        .chartYScale(domain: weights.getYRange(.weekly))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 64)
        .padding(.horizontal, 27)
        .padding(.vertical, 16)
        .background(settings.CardBackground, in: .rect(cornerRadius: CardMetrics.cornerRadius))
    }
}
