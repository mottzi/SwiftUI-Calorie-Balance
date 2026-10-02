import SwiftUI
import WidgetKit
import StoreKit

/// Daily dashboard with calendar, streak, and settings controls.
struct Pager: View {

    @State private var navigation: DayPager
    @State private var todayPageMode: PagerSelection = .first
    
    @State private var showCalendar: Bool = false
    @State private var showSettings: Bool = false
    @State private var currentMonth: Date = .now

    @EnvironmentObject private var AppSettings: Settings

    @Environment(WeightHistory.self) private var weightHistory
    @Environment(Streak.self) private var streak
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.requestReview) private var requestReview
    
    @State private var SliderData = HSlider()
    @State private var manualRefresh = 0
    @State private var calendarRefresh = 0
    
    init(lb: Int, tb: Int) {
        navigation = DayPager(past: lb, future: tb)
    }

    var body: some View {
        if AppSettings.showWelcome {
            Onboarding()
                .environment(SliderData)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if AppSettings.isSettingsInputValid {
                        if showCalendar {
                            CDatePicker(
                                currentMonth: $currentMonth,
                                navigation: navigation,
                                sceneActive: scenePhase == .active,
                                refreshRevision: calendarRefresh,
                                selectDay: { selectDay($0) }
                            )
                        }
                        
                        if streak.showStreaksView {
                            Card(level: .clear, innerPadding: 0) {
                                WeekBalanceGraph(
                                    navigation: navigation,
                                    refreshRevision: manualRefresh + calendarRefresh,
                                    selectDay: { selectDay($0) }
                                )
                            }
                            .padding(.bottom, 15)
                        }
                        
                        DayPageStrip(
                            navigation: navigation,
                            todayPageMode: $todayPageMode
                        )
                        
                        WeightCard()
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
            .scrollDisabled(AppSettings.showWelcome || !AppSettings.isSettingsInputValid)
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
            .task(id: selectedRefreshKey) { await refreshSelectedDay() }
            .task(id: summaryRefreshKey) { await refreshSummary() }
            .refreshable {
                await refreshSelectedDay(force: true)
                await refreshSummary(force: true)
                calendarRefresh += 1
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    todayButton.padding(.leading, toolbarOuterPadding)
                }
                .withoutGlassBackground()

                ToolbarItem(placement: .topBarLeading) {
                    selectedDateLabel
                }
                .withoutGlassBackground()
                .keepVisibleWhenConstrained()

                ToolbarItem(placement: .topBarTrailing) {
                    StreakToolbarButton()
                }
                .withoutGlassBackground()
                .overflowBeforePrimaryItems()

                if #available(iOS 27, *), dynamicType.isAccessibilitySize {
                    ToolbarItem(placement: .topBarPinnedTrailing) {
                        accessibilityActionsMenu
                    }
                    .withoutGlassBackground()
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        calendarButton
                    }
                    .withoutGlassBackground()
                    .keepVisibleWhenConstrained()

                    if #available(iOS 27, *) {
                        ToolbarItem(placement: .topBarPinnedTrailing) {
                            settingsButton.padding(.trailing, toolbarOuterPadding)
                        }
                        .withoutGlassBackground()
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            settingsButton.padding(.trailing, toolbarOuterPadding)
                        }
                        .withoutGlassBackground()
                    }
                }
            }
            .navigationDestination(isPresented: $showSettings) { settingsDestination }
            .safeAreaPadding(.top, 10)
        }
    }

}

extension Pager {

    private var selectedPage: HealthInterface? { navigation.page(for: navigation.selectedDay) }

    // iOS 26 adds more outer toolbar spacing than earlier releases.
    private var toolbarOuterPadding: CGFloat {
        if #available(iOS 26, *) { 8 } else { 16 }
    }

    private var selectedRefreshKey: DayRefreshKey {
        DayRefreshKey(
            day: navigation.selectedDay,
            active: scenePhase == .active && !navigation.isScrolling,
            source: AppSettings.dataSource.rawValue,
            unit: AppSettings.energyUnit.rawValue,
            activeGoal: AppSettings.customCalActive,
            passiveGoal: AppSettings.customCalPassive,
            revision: manualRefresh
        )
    }

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
            revision: manualRefresh
        )
    }

    /// Refreshes only the day being viewed; cancellation keeps rapid swipes cheap.
    private func refreshSelectedDay(force: Bool = false) async {
        guard scenePhase == .active, !navigation.isScrolling, let selectedPage else { return }
        await selectedPage.updateMetrics(force: force)
        guard !Task.isCancelled else { return }
        if selectedPage.id == Calendar.current.startOfDay(for: .now) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Refreshes Today summary data when its inputs change, independent of historical swipes.
    private func refreshSummary(force: Bool = false) async {
        guard scenePhase == .active else { return }
        await AppSettings.updateShow()
        guard !Task.isCancelled else { return }
        let weekPages = navigation.weekPages.filter { $0.id != navigation.selectedDay }
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
        _ = await (weightRefresh, streakRefresh)
    }

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

    // The date describes the selected page in every build configuration.
    private var selectedDateLabel: some View {
        Text(selectedPage?.id.relative ?? "")
            .fontWeight(.semibold)
            .fontDesign(.rounded)
            .foregroundColor(Color("TextColor"))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    private var isTodaySelected: Bool {
        navigation.selectedDay == Calendar.current.startOfDay(for: .now)
    }
    
    private var calendarButton: some View {
        Button(action: {
            withAnimation(.snappy) {
                showCalendar.toggle()
            }
        }
        , label: {
            Image(showCalendar == false ? .customCalendar : .customCalendarSlash)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color("TextColor"))
                .fontWeight(.medium)
        })
        .disabled(AppSettings.showWelcome || !AppSettings.isSettingsInputValid)
    }
    
    private var settingsButton: some View {
        NavigationLink {
            settingsDestination
        } label: {
            Image(systemName: "gear")
                .foregroundColor(Color("TextColor"))
                .fontWeight(.medium)
        }
    }

    private var accessibilityActionsMenu: some View {
        Menu {
            Button {
                withAnimation(.snappy) { showCalendar.toggle() }
            } label: {
                Label("Calendar", systemImage: "calendar")
            }

            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "gear")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(Color("TextColor"))
                .accessibilityLabel("Calendar and Settings")
        }
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
    
    private var todayButton: some View {
        Button {
            if !isTodaySelected {
                let now = Date.now
                selectDay(now)
                if !Calendar.current.isDate(currentMonth, equalTo: now, toGranularity: .month) {
                    withAnimation(.snappy) { currentMonth = now }
                }
            } else {
                withAnimation(.snappy) {
                    todayPageMode = todayPageMode == .first ? .second : .first
                }
            }
        } label: {
            todaySymbol.frame(width: 30)
        }
        .disabled(AppSettings.showWelcome || !AppSettings.isSettingsInputValid)
    }

    private var todaySymbol: some View {
        Image(
            systemName: !isTodaySelected
                ? "arrow.turn.down.left"
                : todayPageMode == .first ? "sun.min.fill" : "moon.stars.fill"
        )
        .foregroundColor(Color("TextColor"))
        .contentTransition(.symbolEffect(.replace))
        .fontWeight(.medium)
    }

}

/// Horizontal day targets that keep their calendar-day identity while browsing.
private struct DayPageStrip: View {
    let navigation: DayPager
    @Binding var todayPageMode: PagerSelection

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
            .padding(.bottom, 20)
        }
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

/// Toolbar control for the streak count and chart visibility.
private struct StreakToolbarButton: View {

    @EnvironmentObject private var settings: Settings

    @Environment(Streak.self) private var streak

    var body: some View {
        Button {
            streak.toggleStreaksView()
        } label: {
            let color = settings.weightGoal == .lose ? settings.burnedColor : settings.consumedColor
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(color.brighten(-0.1).gradient)
                    .fontWeight(.bold)

                Text("\(streak.streaks)")
                    .font(.callout)
                    .fontDesign(.rounded)
                    .fontWeight(.bold)
                    .foregroundStyle(Color("TextColor"))
            }
        }
        .disabled(settings.showWelcome || !settings.isSettingsInputValid)
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

private extension ToolbarContent {

    @ToolbarContentBuilder
    func withoutGlassBackground() -> some ToolbarContent {
        if #available(iOS 26, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }

    @ToolbarContentBuilder
    func keepVisibleWhenConstrained() -> some ToolbarContent {
        if #available(iOS 27, *) {
            visibilityPriority(.high)
        } else {
            self
        }
    }

    @ToolbarContentBuilder
    func overflowBeforePrimaryItems() -> some ToolbarContent {
        if #available(iOS 27, *) {
            visibilityPriority(.low)
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

}
