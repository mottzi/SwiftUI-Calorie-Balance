import SwiftUI
import WidgetKit
import StoreKit

/// Daily dashboard with calendar, streak, and settings controls.
struct Pager: View {

    @State private var navigation: DayPager
    @State private var todayPageMode: PagerSelection = .first
    
    @State private var showCalendar: Bool = false
    @State private var currentMonth: Date = .now

    @EnvironmentObject private var AppSettings: Settings

    @Environment(WeightDataViewModel.self) private var WeightViewModel
    @Environment(Streak.self) private var streak
    @Environment(\.scenePhase) private var scenePhase
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
                                selectDay: selectDay
                            )
                        }
                        
                        if streak.showStreaksView {
                            Card(level: .clear, innerPadding: 0, subtitle: { EmptyView() }) {
                                WeekBalanceGraph(
                                    DataPoints: navigation.weekPages,
                                    selectedDay: navigation.selectedDay,
                                    selectDay: selectDay
                                )
                                    .padding(.horizontal, 12)
                            }
                            .padding(.bottom, 15)
                        }
                        
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 0) {
                                ForEach(navigation.pages, id: \.id) {
                                    Dashboard(todayPageMode: $todayPageMode)
                                        .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 10.0)
                                        .environment($0)
                                        .id($0.id)
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.bottom, 20)
                        }
                        .scrollTargetBehavior(.paging)
                        .scrollIndicators(.hidden)
                        .scrollPosition(id: scrollDay)
                        
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
            .softTopScrollEdge()
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
                await refreshSelectedDay()
                await refreshSummary()
                calendarRefresh += 1
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if #available(iOS 26, *) {
                        todayButton
                    } else {
                        todayButton.padding(.leading, 16)
                    }
                }
                
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        selectedDateLabel
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        selectedDateLabel
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        streak.toggleStreaksView()
                    } label: {
                        let color = (AppSettings.weightGoal == .lose ? AppSettings.burnedColor : AppSettings.consumedColor)
                        
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
                    .disabled(AppSettings.showWelcome || !AppSettings.isSettingsInputValid)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    calendarButton
                }

                if #available(iOS 26, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26, *) {
                        settingsButton
                    } else {
                        settingsButton.padding(.trailing, 16)
                    }
                }
            }
            .safeAreaPadding(.top, 10)
        }
    }

}

extension Pager {

    private var selectedPage: HealthInterface? { navigation.page(for: navigation.selectedDay) }

    private var scrollDay: Binding<Date?> {
        Binding(
            get: { navigation.selectedDay },
            set: { day in
                guard let day else { return }
                navigation.selectedDay = Calendar.current.startOfDay(for: day)
            }
        )
    }

    private var selectedRefreshKey: DayRefreshKey {
        DayRefreshKey(
            day: navigation.selectedDay,
            active: scenePhase == .active,
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
    private func refreshSelectedDay() async {
        guard scenePhase == .active, let selectedPage else { return }
        await selectedPage.updateMetrics()
        guard !Task.isCancelled else { return }
        if selectedPage.id == Calendar.current.startOfDay(for: .now) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Refreshes Today summary data when its inputs change, independent of historical swipes.
    private func refreshSummary() async {
        guard scenePhase == .active else { return }
        await AppSettings.updateShow()
        guard !Task.isCancelled else { return }
        for page in navigation.weekPages where page.id != navigation.selectedDay {
            guard !Task.isCancelled else { return }
            await page.updateMetrics()
        }
        guard !Task.isCancelled else { return }
        await WeightViewModel.fetchData()
        await streak.updateStreaks()
    }

    /// Animates navigation to the selected calendar day.
    private func selectDay(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        // prepare scroll targets without animating inserted pages
        withTransaction(Transaction(animation: nil)) {
            navigation.ensurePagesForSelection(day)
        }
        withAnimation(.snappy) { navigation.selectedDay = day }
    }

    // The date describes the selected page; it does not share a glass background
    // with the adjacent day/night action. Keep the development shortcut available.
    private var selectedDateLabel: some View {
        #if !DEBUG
        Text(selectedPage?.id.relative ?? "")
            .fontWeight(.semibold)
            .fontDesign(.rounded)
            .foregroundColor(Color("TextColor"))
            .transaction { transaction in
                transaction.animation = nil
            }
        #else
        Button {
            withAnimation(.snappy) {
                selectedPage?.randomizeHealthData()

                let start = Double.random(in: 60 ... 150)
                let end = start - Double.random(in: 1 ... 5)

                WeightViewModel.randomizeWeightData(start: start, end: end)
            }
        } label: {
            Text(selectedPage?.id.relative ?? "")
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundColor(Color("TextColor"))
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        #endif
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
        } label: {
            Image(systemName: "gear")
                .foregroundColor(Color("TextColor"))
                .fontWeight(.medium)
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
            if #available(iOS 26, *) {
                todaySymbol
            } else {
                todaySymbol.frame(width: 30)
            }
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


#Preview { PreviewPager }

// The navigation bar reads the top edge of its scroll view.
// Keep the default effect on older iOS releases.
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
