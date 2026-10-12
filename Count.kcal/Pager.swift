import SwiftUI
import WidgetKit
import StoreKit

/// Daily dashboard with calendar, streak, and settings controls.
struct Pager: View {

    @State private var navigation: DayPager
    @State private var todayPageMode = TodayPageMode()
    
    @State private var showCalendar: Bool = false
    @State private var showSettings: Bool = false
    @State private var currentMonth: Date = .now
    @State private var calendarDays: [HealthInterface] = []

    @EnvironmentObject private var AppSettings: Settings

    @Environment(WeightHistory.self) private var weightHistory
    @Environment(Streak.self) private var streak
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    
    @State private var SliderData = HSlider()
    @State private var healthDataMode = HealthDataMode.shared
    @State private var manualRefresh = 0
    @State private var calendarRefresh = 0
    
    init(lb: Int, tb: Int) {
        navigation = DayPager(past: lb, future: tb)
    }

    var body: some View {
        Group {
            if AppSettings.showWelcome {
                Onboarding()
                    .environment(SliderData)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if AppSettings.calorieDataState != .incomplete {
                            if showCalendar {
                                CDatePicker(
                                    currentMonth: $currentMonth,
                                    days: calendarDays,
                                    navigation: navigation,
                                    sceneActive: scenePhase == .active,
                                    refreshRevision: calendarRefresh,
                                    selectDay: { selectDay($0) }
                                )
                            }

                            if streak.showStreaksView {
                                WeekBalanceGraph(
                                    navigation: navigation,
                                    refreshRevision: manualRefresh + calendarRefresh,
                                    selectDay: { selectDay($0) }
                                )
                                .padding(.bottom, 14)
                            }

                            DayPageStrip(
                                navigation: navigation,
                                todayPageMode: $todayPageMode
                            )

                            WeightCard(refreshRevision: manualRefresh + calendarRefresh)
                        } else {
                            ContentUnavailableView(
                                "Calorie data incomplete",
                                systemImage: "gear.badge.xmark",
                                description: Text("Set up calorie data and goals")
                            )
                            .padding(.top, 35)
                        }
                    }
                }
                .softTopScrollEdge()
                .scrollDisabled(AppSettings.showWelcome || AppSettings.calorieDataState == .incomplete)
                .frame(maxHeight: .infinity)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        navigation.rolloverIfNeeded()
                    } else if newPhase == .inactive {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    navigation.rolloverIfNeeded()
                }
                .onChange(of: navigation.selectedDay) { _, _ in
                    // extend the range without animating inserted pages
                    withTransaction(Transaction(animation: nil)) {
                        navigation.ensureSelectionBuffer()
                    }
                }
                .onChange(of: healthDataMode.revision) {
                    // Keep the visible day's model and refresh it with the new source revision.
                    weightHistory.reset()
                    streak.reset()
                    manualRefresh += 1
                    calendarRefresh += 1
                }
                .onChange(of: currentMonth) { _, month in
                    guard showCalendar else { return }
                    calendarDays = navigation.calendarPages(for: month)
                }
                .task(id: selectedRefreshKey) { await refreshSelectedDay() }
                .task(id: summaryRefreshKey) { await refreshSummary() }
                .refreshable {
                    await refreshSelectedDay(force: true)
                    await refreshSummary(force: true)
                    calendarRefresh += 1
                }
            }
        }
        // Keep navigation attached while onboarding replaces the dashboard.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(AppSettings.showWelcome ? .hidden : .visible, for: .navigationBar)
        .toolbar { Toolbar }
        .navigationDestination(isPresented: $showSettings) { settingsDestination }
        .safeAreaPadding(.top, AppSettings.showWelcome ? 0 : 10)
    }

}

extension Pager {

    /// Selects a day, optionally animating the dashboard scroll.
    private func selectDay(_ date: Date, animated: Bool = true) {
        let day = Calendar.current.startOfDay(for: date)
        // prepare scroll targets without animating inserted pages
        withTransaction(Transaction(animation: nil)) {
            navigation.ensurePagesForSelection(day)
        }
        if animated {
            withAnimation(.snappy) { navigation.selectDay(day, animated: true) }
        } else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { navigation.selectDay(day) }
        }
    }

    private var selectedRefreshKey: DayRefreshKey {
        DayRefreshKey(
            day: navigation.selectedDay,
            active: scenePhase == .active,
            source: AppSettings.dataSource.rawValue,
            unit: AppSettings.energyUnit.rawValue,
            activeGoal: AppSettings.customCalActive,
            passiveGoal: AppSettings.customCalPassive,
            revision: manualRefresh,
            healthRevision: healthDataMode.revision
        )
    }

    /// Prioritizes the visible day while shared loads survive rapid swipes.
    private func refreshSelectedDay(force: Bool = false) async {
        guard scenePhase == .active, let selectedPage else { return }
        await selectedPage.updateMetrics(animated: false, force: force)
        guard !Task.isCancelled else { return }
        if selectedPage.id == Calendar.current.startOfDay(for: .now) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private var selectedPage: HealthInterface? { navigation.page(for: navigation.selectedDay) }

    private var summaryRefreshKey: SummaryRefreshKey {
        SummaryRefreshKey(
            today: navigation.weekPages.last?.id ?? Calendar.current.startOfDay(for: .now),
            active: scenePhase == .active,
            source: AppSettings.dataSource.rawValue,
            unit: AppSettings.energyUnit.rawValue,
            weightUnit: AppSettings.weightUnit.rawValue,
            weightGoal: AppSettings.weightGoal.rawValue,
            balanceGoal: AppSettings.balanceGoal,
            activeGoal: AppSettings.customCalActive,
            passiveGoal: AppSettings.customCalPassive,
            revision: manualRefresh,
            healthRevision: healthDataMode.revision
        )
    }

    /// Refreshes Today summary data when its inputs change, independent of historical swipes.
    private func refreshSummary(force: Bool = false) async {
        guard scenePhase == .active else { return }
        let weekPages = navigation.weekPages.filter { $0.id != navigation.selectedDay }
        // Start independent summaries together so estimates cannot delay the visible cards.
        async let estimatesRefresh: Void = AppSettings.updateShow()
        async let weightRefresh: Void = weightHistory.fetchData()
        async let streakRefresh: Void = streak.updateStreaks()
        await withTaskGroup(of: Void.self) { group in
            for page in weekPages {
                group.addTask {
                    guard !Task.isCancelled else { return }
                    await page.updateMetrics(force: force)
                }
            }
        }
        _ = await (estimatesRefresh, weightRefresh, streakRefresh)
    }

    private var Toolbar: some ToolbarContent {
        DashboardToolbar(
            navigation: navigation,
            todayPageMode: $todayPageMode,
            showCalendar: $showCalendar,
            showSettings: $showSettings,
            currentMonth: $currentMonth,
            calendarDays: $calendarDays,
            controlsDisabled: AppSettings.showWelcome || AppSettings.calorieDataState == .incomplete,
            streakColor: AppSettings.weightGoal == .lose ? AppSettings.burnedColor : AppSettings.consumedColor,
            selectDay: { selectDay($0) }
        )
    }

    private var settingsDestination: some View {
        SettingsPage()
            .environmentObject(AppSettings)
            .environment(SliderData)
            .onDisappear {
                AppSettings.closedSettings += 1
                manualRefresh += 1
                calendarRefresh += 1
                Task {
                    #if !DEBUG
                    if AppSettings.isSettingsInputValid && AppSettings.closedSettings >= 1 {
                        try? await Task.sleep(for: .seconds(0.2))
                        requestReview()
                        AppSettings.closedSettings = 0
                    }
                    #endif
                }
            }
    }

}

/// Horizontal day targets that keep their calendar-day identity while browsing.
private struct DayPageStrip: View {
    let navigation: DayPager

    @Binding var todayPageMode: TodayPageMode

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(navigation.pages) { page in
                    Dashboard(todayPageMode: $todayPageMode)
                        .containerRelativeFrame(.horizontal)
                        .environment(page)
                        .id(page.id)
                }
            }
            .scrollTargetLayout()
        }
        .padding(.bottom, 20)
        .scrollIndicators(.hidden)
        .calendarPaging(
            selection: navigation.selectedDay,
            animated: navigation.animatesDayScroll,
            onSelect: { navigation.selectDay($0) },
            onActivity: { scrolling in
                navigation.dayIsScrolling = scrolling
                navigation.ensureSelectionBuffer()
            }
        )
    }
}

#Preview { PreviewPager }

extension View {

    @ViewBuilder
    func softTopScrollEdge() -> some View {
        if #available(iOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }

}

/// Values that can change the selected day's HealthKit result.
private struct DayRefreshKey: Hashable {

    let day: Date
    let active: Bool
    let source: Int
    let unit: String
    let activeGoal: Int
    let passiveGoal: Int
    let revision: Int
    let healthRevision: String

}

/// Inputs for Today charts, streak, and weight summaries.
private struct SummaryRefreshKey: Hashable {

    let today: Date
    let active: Bool
    let source: Int
    let unit: String
    let weightUnit: String
    let weightGoal: Int
    let balanceGoal: Int
    let activeGoal: Int
    let passiveGoal: Int
    let revision: Int
    let healthRevision: String

}
