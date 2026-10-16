#if DEBUG && targetEnvironment(simulator)
import SwiftUI

struct WeightChartScenarioView: View {
    let scenario: WeightChartScenario
    @State private var history: WeightHistory

    init(scenario: WeightChartScenario) {
        self.scenario = scenario
        let history = WeightHistory()
        let latest = scenario.dailyAverages.last { $0.weightAvg != nil }
        history.apply(WeightHistorySnapshot(
            dailyAverages: scenario.dailyAverages,
            latestWeight: latest?.weightAvg,
            latestWeightDate: latest?.date,
            unit: Settings.shared.weightUnit.rawValue,
            updatedAt: scenario.end
        ))
        _history = State(initialValue: history)
    }

    var body: some View {
        VStack(spacing: 16) {
            ForEach([WeightPage.weekly, .monthly], id: \.rawValue) { page in
                Card(innerPadding: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: page == .weekly ? "Weekly" : "Monthly")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 22)
                            .padding(.top, 12)
                        ProgressWeightChart(page: page)
                            .padding(.top, 22)
                            .frame(height: 130)
                            .padding(.top, 12)
                            .padding(.bottom, 2)
                            .padding(.leading, 22)
                            .padding(.trailing, 16)
                        Text(verbatim: "Y \(history.getYBottomRange(page)) ... \(history.getYTopRange(page)) · \(history.validData(page).count) readings")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(12)
                    }
                }
            }
            Text(verbatim: "Ending \(scenario.end.formatted(date: .numeric, time: .omitted))")
                .font(.caption)
        }
        .environment(history)
    }
}
#endif
