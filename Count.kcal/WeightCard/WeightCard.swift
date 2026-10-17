import SwiftUI
import Charts

/// Weight history with weekly and monthly chart pages.
struct WeightCard: View {


    @State private var pageSelection: PagerSelection? = .first
    @State private var progress = ProgressHistory()
    @State private var today = Calendar.current.startOfDay(for: Date.now)

    @Environment(\.scenePhase) private var scenePhase
    @Environment(WeightHistory.self) private var weights

    @EnvironmentObject private var settings: Settings

    var refreshRevision = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Card("Progress", innerPadding: 0) {
                VStack(spacing: 0) {
                    WeightTopBar(pageSelection: $pageSelection)
                        .padding(.horizontal, 27)
                        .padding(.top, 20)
                    
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            progressPage(page: .weekly, period: .week)
                                .id(PagerSelection.first)
                                .containerRelativeFrame(.horizontal)
                            
                            progressPage(page: .monthly, period: .month)
                                .id(PagerSelection.second)
                                .containerRelativeFrame(.horizontal)
                        }
                        .scrollTargetLayout()
                    }
                    .scrollPosition(id: $pageSelection)
                    .scrollTargetBehavior(.paging)
                    .scrollIndicators(.hidden)
                    .animation(.snappy, value: pageSelection)
                }
            }
        }
        .task(id: refreshKey) {
            guard scenePhase == .active else { return }
            await progress.refresh()
            for await _ in HealthRepository.shared.weightChanges() {
                guard !Task.isCancelled else { return }
                await weights.fetchData()
                await progress.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            today = Calendar.current.startOfDay(for: Date.now)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { today = Calendar.current.startOfDay(for: Date.now) }
        }
    }

}

extension WeightCard {

    private func progressPage(page: WeightPage, period: ProgressPeriod) -> some View {
        VStack(spacing: 0) {
            ProgressWeightChart(page: page)
                // Reserve space for labels above the highest weekly point.
                .padding(.top, 22)
                .frame(height: 130)
                .padding(.top, 2)
                .padding(.bottom, 2)
                .padding(.leading, 22)
                .padding(.trailing, 16)

            ProgressMetrics(history: progress, period: period)
                .padding(.bottom, 8)
                .padding(.horizontal, 27)
        }
    }

    private var refreshKey: RefreshKey {
        RefreshKey(
            active: scenePhase == .active,
            today: today,
            policy: ProgressPolicy(settings: settings),
            healthRevision: HealthRepository.shared.revision,
            refreshRevision: refreshRevision
        )
    }

    private struct RefreshKey: Equatable {
        let active: Bool
        let today: Date
        let policy: ProgressPolicy
        let healthRevision: String
        let refreshRevision: Int
    }

}

struct ProgressWeightChart: View {

    @Environment(WeightHistory.self) private var weights

    let page: WeightPage

    var body: some View {
        if weights.validData(page).isEmpty {
            if weights.isLoading || (weights.updatedAt == nil && !weights.refreshFailed) {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "scalemass")
                        .font(.title3)
                        .accessibilityHidden(true)
                    Text("No weight measurements")
                        .font(.footnote)
                }
                .foregroundStyle(Color("SecondaryTextColor"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if page == .weekly {
            WeeklyChart()
                .accessibilityLabel("Weekly weight history")
        } else {
            MonthlyChart()
                .accessibilityLabel("Monthly weight history")
        }
    }

}

#Preview { PreviewPager }
