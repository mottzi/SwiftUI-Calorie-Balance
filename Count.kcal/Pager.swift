import SwiftUI
import WidgetKit
import StoreKit
import SQLiteData

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
    @State private var manualRefresh = 0
    @State private var calendarRefresh = 0

    private let repository = HealthRepository.shared
    
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

                            ForEach(AppSettings.dashboardProgressPosition.sections) { section in
                                switch section {
                                case .daily:
                                    DayPageStrip(
                                        navigation: navigation,
                                        selectedDay: navigation.selectedDay,
                                        animated: navigation.animatesDayScroll,
                                        todayPageMode: $todayPageMode
                                    )
                                case .progress:
                                    VStack(spacing: 20) {
                                        WeightCard(refreshRevision: manualRefresh + calendarRefresh)
                                        NavigationLink {
                                            SharingOverviewView(runtime: .shared)
                                        } label: {
                                            Label("Sharing", systemImage: "person.2.fill")
                                        }
                                        .modifier(SharingActionAppearance())
                                        .padding(.top, 14)
                                        .accessibilityHint("Open shared calorie cards and requests")
                                    }
                                    .padding(.bottom, AppSettings.dashboardProgressPosition == .above ? 20 : 0)
                                }
                            }
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
                .onChange(of: repository.revision) {
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
        .modifier(StreakDayChoices())
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
            healthRevision: repository.revision,
            marketingGoals: HealthDataMode.isMarketingDataEnabled
                ? [AppSettings.balanceGoal, AppSettings.proteinGoal, AppSettings.carbsGoal, AppSettings.fatsGoal] : []
        )
    }

    /// Prioritizes the visible day while shared loads survive rapid swipes.
    private func refreshSelectedDay(force: Bool = false) async {
        guard scenePhase == .active, let selectedPage else { return }
        await selectedPage.updateMetrics(animated: false, force: force)
        SharingRuntime.shared.schedulePublication(settings: AppSettings)
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
            healthRevision: repository.revision
        )
    }

    /// Refreshes Today summary data when its inputs change, independent of historical swipes.
    private func refreshSummary(force: Bool = false) async {
        guard scenePhase == .active else { return }
        let weekPages = navigation.weekPages.filter { $0.id != navigation.selectedDay }
        // Marketing nutrients use the goals derived from the sample energy budget.
        // Resolve those goals before starting the week's snapshots.
        let marketing = repository.usesMarketingSamples
        if marketing { await AppSettings.updateShow() }
        guard !Task.isCancelled else { return }
        // Start independent summaries together so estimates cannot delay the visible cards.
        async let estimatesRefresh: Void = marketing ? () : AppSettings.updateShow()
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

/// Saved exclusions update the streak even if its weekly chart is hidden.
private struct StreakDayChoices: ViewModifier {

    @Environment(Streak.self) private var streak

    @FetchAll private var records: [StoredDayChoice]

    func body(content: Content) -> some View {
        let choices = AppDatabase.choices(records, sampleData: HealthDataMode.shared.usesSampleData)
        content.onChange(of: choices, initial: true) {
            streak.updateDayChoices(choices)
        }
    }

}

/// Horizontal day targets that keep their calendar-day identity while browsing.
private struct DayPageStrip: View {
    let navigation: DayPager
    let selectedDay: Date
    let animated: Bool

    @Binding var todayPageMode: TodayPageMode
    @Namespace private var viewport
    @State private var centeredPage: Date?

    var body: some View {
        CalendarPageReturn(
            selection: selectedDay,
            animated: animated,
            pageDays: 1
        ) { selection, animated, onArrival in
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 0) {
                    ForEach(navigation.pages) { page in
                        dashboard(page)
                            .containerRelativeFrame(.horizontal)
                            .id(page.id)
                            .calendarPagePosition(
                                id: page.id, selection: selection, viewport: viewport,
                                onCenter: { centeredPage = $0 }, onArrival: onArrival
                            )
                    }
                }
                .scrollTargetLayout()
            }
            .coordinateSpace(name: viewport)
            .scrollIndicators(.hidden)
            .calendarPaging(
                selection: selection,
                centeredPage: centeredPage,
                animated: animated,
                onSelect: { navigation.selectDay($0) },
                onActivity: { scrolling in
                    navigation.dayIsScrolling = scrolling
                    navigation.ensureSelectionBuffer()
                }
            )
        } destination: { date in
            if let page = navigation.page(for: date) {
                dashboard(page)
            }
        }
        .padding(.bottom, 20)
    }

    private func dashboard(_ page: HealthInterface) -> some View {
        Dashboard(todayPageMode: $todayPageMode)
            .environment(page)
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
    let marketingGoals: [Int]

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
