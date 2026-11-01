import SwiftUI

// A self-contained Canvas fixture. It renders the app's real dashboard views
// without querying HealthKit or changing the simulator's saved data.
var PreviewPager: some View {
    #if DEBUG
    DatabaseGate { DashboardSamplePreview() }
    #else
    EmptyView()
    #endif
}

#if DEBUG
#Preview("Balance bar") {
    BarBalanceGraph(mode: .now)
        .environment(HealthInterface(.example(for: .now, balance: .deficit)))
        .environmentObject(Settings.shared)
        .frame(height: 44)
        .padding(.trailing, 80)
        .padding(.leading, 30)
        .fontDesign(.rounded)
}

#Preview("Midnight balance") {
    DatabaseGate { DashboardSamplePreview(todayPageMode: .second) }
}

private struct DashboardSamplePreview: View {

    @State private var pages: [HealthInterface]
    @State private var selectedPage: HealthInterface?
    @State private var todayPageMode = TodayPageMode()
    @State private var weightModel: WeightHistory
    @State private var streak: Streak

    init(todayPageMode: PagerSelection = .first) {
        let today = Calendar.current.startOfDay(for: .now)
        let samplePages = (0...6).reversed().map { daysAgo in
            let date = today.subtractDays(daysAgo)
            var data = HealthData.example(for: date)
            data.burnedActive = daysAgo == 0 ? 257 : 340 + daysAgo * 48
            data.burnedPassive = daysAgo == 0 ? 1_231 : 1_680 + daysAgo * 19
            data.burnedActive7 = 490
            data.burnedPassive7 = 1_730
            // Today's intake falls between Now and Midnight burn to exercise a sign change.
            data.consumed = daysAgo == 0 ? 1_660 : 1_940 + daysAgo * 37
            data.carbs = daysAgo == 0 ? 141 : 210
            data.fats = daysAgo == 0 ? 55 : 72
            data.protein = daysAgo == 0 ? 91 : 118
            data.steps = daysAgo == 0 ? 4_327 : 7_800 + daysAgo * 230
            return HealthInterface(data)
        }
        _pages = State(initialValue: samplePages)
        _selectedPage = State(initialValue: samplePages.last)
        _todayPageMode = State(initialValue: TodayPageMode(selection: todayPageMode))

        let weights = WeightHistory()
        weights.dailyAverages = (0..<37).reversed().map { daysAgo in
            WeightChartData(
                date: today.subtractDays(daysAgo),
                weightAvg: 81.5 - Double(36 - daysAgo) * 0.05
            )
        }
        weights.latestWeight = 79.7
        weights.latestWeightDate = today
        _weightModel = State(initialValue: weights)

        let repository = HealthRepository(source: SampleHealthDataSource())
        for page in samplePages {
            repository.replaceDevelopmentMeasurements(page.sample, energyUnit: .kcal)
        }
        _streak = State(initialValue: Streak(repository: repository))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Settings.shared.AppBackground
                    .ignoresSafeArea(.all)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Card(level: .clear, innerPadding: 0) {
                            WeekBalanceChart(
                                dataPoints: pages,
                                selectedDay: selectedPage?.id ?? Calendar.current.startOfDay(for: .now),
                                selectDay: { day in
                                    selectedPage = pages.first { $0.id == day }
                                }
                            )
                            .padding(.horizontal, 4)
                        }
                        .padding(.bottom, 15)

                        if let selectedPage {
                            Dashboard(
                                todayPageMode: $todayPageMode,
                                nutrientGoals: NutrientGoals(carbs: 177, fats: 69, protein: 111)
                            )
                                .environment(selectedPage)
                                .padding(.bottom, 20)
                        }

                        WeightCard()
                    }
                }
                .safeAreaPadding(.top, 10)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Label("Today", systemImage: "sun.min.fill")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Image(systemName: "flame.fill")
                        Text("\(streak.streaks)")
                        Image(systemName: "calendar")
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .environmentObject(Settings.shared)
        .environment(weightModel)
        .environment(streak)
        .task { await streak.updateStreaks() }
    }

}
#endif
