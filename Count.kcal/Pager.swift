import SwiftUI
import Observation
import WidgetKit
import StoreKit

struct Pager: View
{    
    @State private var firstLaunch = Date.now

    @State private var Pages: [HealthInterface]
    @State private var selectedPage: HealthInterface?
    @State private var ignoreChanges: Bool = false
    @State private var todayPageMode: PagerSelection? = .first
    
    @State private var showCalendar: Bool = false
    @State private var currentMonth: Date = .now

    @EnvironmentObject private var AppSettings: Settings
    @Environment(WeightDataViewModel.self) private var WeightViewModel
    @Environment(Streak.self) private var streak
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.requestReview) private var requestReview
    
    @State private var SliderData = HSlider()
    
    func findPage(for date: Date) -> HealthInterface?
    {
        Pages.first { $0.sample.date.isSameDay(as: date) }
    }
    
    var FirstPages: [HealthInterface]
    {
        var pages: [HealthInterface] = []
        let current = Date.now
        
        for i in (0...5).reversed()
        {
            guard let p = findPage(for: current.subtractDays(i)) else { continue }
            pages.append(p)
        }
        
        return pages
    }
        
    var body: some View
    {
        if AppSettings.showWelcome
        {
            Onboarding()
                .environment(SliderData)
        }
        else
        {
            ScrollView(showsIndicators: false)
            {
                VStack(spacing: 0)
                {
                    if AppSettings.isSettingsInputValid
                    {
                        if showCalendar
                        {
                            CDatePicker(Pages: $Pages, selectedPage: $selectedPage, ignoreChanges: $ignoreChanges, currentMonth: $currentMonth)
                        }
                        
                        if streak.showStreaksView
                        {
                            Card(level: .clear, innerPadding: 0, subtitle: { EmptyView() })
                            {
                                WeekBalanceGraph(DataPoints: FirstPages, Pages: $Pages, selectedPage: $selectedPage, ignoreChanges: $ignoreChanges)
                                    .task
                                    {
                                        for page in FirstPages
                                        {
                                            await page.updateMetrics(cache: false)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                            }
                            .padding(.bottom, 15)
                        }
                        
                        ScrollView(.horizontal)
                        {
                            LazyHStack(spacing: 0)
                            {
                                ForEach(Pages, id: \.self)
                                {
                                    Dashboard(todayPageMode: $todayPageMode)
                                        .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 10.0)
                                        .environment($0)
                                        .id($0)
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.bottom, 20)
                        }
                        .scrollTargetBehavior(.paging)
                        .scrollIndicators(.hidden)
                        .scrollPosition(id: $selectedPage)
                        
                        WeightCard()
                        .onAppear
                        {
                            Task.detached(priority: .userInitiated)
                            {
                                await WeightViewModel.fetchData()
                            }
                        }
                    }
                    else
                    {
                        ContentUnavailableView("Calorie data incomplete", systemImage: "gear.badge.xmark", description: Text("Set up calorie data and goals"))
                            .padding(.top, 35)
                    }
                }
            }
            .scrollDisabled(AppSettings.showWelcome || !AppSettings.isSettingsInputValid)
            .frame(maxHeight: .infinity)
            .onChange(of: scenePhase)
            { _, newPhase in
                if newPhase == .active
                {
                    let now = Date.now
                    
                    if !now.isSameDay(as: firstLaunch)
                    {
                        firstLaunch = now
                        
                        if let today = findPage(for: now)
                        {
                            withAnimation(.snappy)
                            {
                                selectedPage = today
                            }
                        }
                    }
                    
                    Task.detached
                    {
                        await selectedPage?.updateMetrics(cache: false)
                        await WeightViewModel.fetchData()
                        await streak.updateStreaks()
                        
                        for page in await FirstPages
                        {
                            await page.updateMetrics(cache: false)
                        }
                        
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
                else if newPhase == .inactive
                {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            .refreshable
            {
                await selectedPage?.updateMetrics(cache: false)
                await WeightViewModel.fetchData()
                
                for page in FirstPages
                {
                    await page.updateMetrics(cache: false)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .topBarLeading)
                {
                    todayButton
                        .padding(.leading, 16)
                        .offset(y: 0)
                }
                
                ToolbarItem(placement: .topBarTrailing)
                {
                    Button
                    {
                        streak.toggleStreaksView()
                    }
                    label:
                    {
                        let color = (AppSettings.weightGoal == .lose ? AppSettings.burnedColor : AppSettings.consumedColor)
                        
                        HStack(spacing: 4)
                        {
                            Image(systemName: "flame.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(color.brighten(-0.1).gradient)
                                .fontWeight(.bold)
                            
                            Text("\(streak.streaks)")
                                .font(.callout)
                                .fontDesign(.rounded)
                                .fontWeight(.bold)
                                .foregroundStyle(Color("TextColor"))
                                .offset(y: 2)
                                .task { await streak.updateStreaks() }
                        }
                    }
                    .disabled(AppSettings.showWelcome || !AppSettings.isSettingsInputValid)
                }
                
                ToolbarItem(placement: .topBarLeading)
                {
                    #if !DEBUG
                    Text(selectedPage?.sample.date.relative ?? String(""))
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundColor(Color("TextColor"))
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                    #else
                    Button
                    {
                        withAnimation(.snappy)
                        {
                           selectedPage?.randomizeHealthData()
    
                           /*for page in FirstPages
                           {
                               page.randomizeHealthData()
                           }*/
    
                           let start = Double.random(in: 60 ... 150)
                           let end = start - Double.random(in: 1 ... 5)
    
                           WeightViewModel.randomizeWeightData(start: start, end: end)
                       }
                    }
                    label:
                    {
                        Text(selectedPage?.sample.date.relative ?? "")
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .foregroundColor(Color("TextColor"))
                            .transaction { transaction in
                                transaction.animation = nil
                            }
                    }
                    #endif
                }
                
                ToolbarItem(placement: .topBarTrailing)
                {
                    calendarButton
                }
                
                ToolbarItem(placement: .topBarTrailing)
                {
                    settingsButton
                        .padding(.trailing, 16)
                }
            }
            .safeAreaPadding(.top, 10)
            .onAppear
            {
                selectedPage = findPage(for: .now)
                
                Task
                {
                    AppSettings.showResting = await HKRepository.shared.cumDataWeek(fetch: .basalEnergyBurned, for: .now)
                    AppSettings.showActive = await HKRepository.shared.cumDataWeek(fetch: .activeEnergyBurned, for: .now)
                }
            }
            .onChange(of: selectedPage)
            { oldPage, newPage in
                guard let newPage else { return }
                
                // data updates on background "thread"
                Task.detached(priority: .userInitiated)
                {
                    // if selected page is today
                    if newPage.isTodayPage
                    {
                        // fetch data of newly selected today page
                        await newPage.updateMetrics(cache: false)
                        
                        // reload widgets.
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    else
                    {
                        // restore cached data of newly selected page
                        await newPage.updateMetrics(cache: false)
                    }
                    
                    // reset data of old page, data will reload (from cache) on next selection, ensures load animations
                    // await oldPage?.clearData()
                }
                
                // manipulation of Pages
                if !ignoreChanges
                {
                    if let lastPage = Pages.last, newPage == lastPage
                    {
                        Pages.append(HealthInterface(.empty(for: newPage.sample.date.tomorrow)))
                    }
                    else if let firstPage = Pages.first, newPage == firstPage
                    {
                        Pages.insert(HealthInterface(.empty(for: newPage.sample.date.yesterday)), at: 0)
                    }
                }
                else
                {
                    ignoreChanges = false
                }
            }
        }
    }
    
    init(lb: Int, tb: Int)
    {
        var pastPresentData: [HealthInterface] = []

        for i in (1...lb).reversed()
        {
            pastPresentData.append(HealthInterface(.empty(for: .now.subtractDays(i))))
        }

        pastPresentData.append(HealthInterface(.empty(for: .now)))
        
        var allData: [HealthInterface] = pastPresentData.map { HealthInterface($0.sample/*.copy()*/) }

        for i in (1...tb)
        {
            allData.append(HealthInterface(.empty(for: .now.addDays(i))))
        }

        self._Pages = State(initialValue: allData)
    }
    
    private var isTodaySelected: Bool
    {
        selectedPage?.isTodayPage ?? false
    }
    
    private var calendarButton: some View
    {
        Button(action:
        {
            withAnimation(.snappy)
            {
                showCalendar.toggle()
            }
        }
        , label:
        {
            Image(showCalendar == false ? .customCalendar : .customCalendarSlash)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color("TextColor"))
                .fontWeight(.medium)
        })
        .disabled(AppSettings.showWelcome || !AppSettings.isSettingsInputValid)
    }
    
    private var settingsButton: some View
    {
        NavigationLink
        {
            SettingsPage()
                .environmentObject(AppSettings)
                .environment(SliderData)
                .onDisappear
                {
                    AppSettings.closedSettings += 1
                    
                    Task
                    {
                        await selectedPage?.updateMetrics()
                        await WeightViewModel.fetchData()
                        
                        #if !DEBUG
                        if AppSettings.isSettingsInputValid && AppSettings.closedSettings >= 1
                        {
                            try? await Task.sleep(for: .seconds(0.2))
                            
                            requestReview()
                            AppSettings.closedSettings = 0
                        }
                        #endif
                    }
                }
        }
        label:
        {
            Image(systemName: "gear")
                .foregroundColor(Color("TextColor"))
                .fontWeight(.medium)
        }
    }
    
    private var todayButton: some View
    {
        Button
        {
            if !isTodaySelected
            {
                let now = Date()
                
                if let todayPage = findPage(for: now)
                {
                    var t = Transaction(animation: .snappy)
                    t.scrollToToday = true
                    
                    withTransaction(t)
                    {
                        selectedPage = todayPage
                    }
                    
                    if !Calendar.current.isDate(currentMonth, equalTo: now, toGranularity: .month)
                    {
                        withAnimation(.snappy)
                        {
                            currentMonth = now
                        }
                    }
                }
            }
            else
            {
                withAnimation(.snappy)
                {
                    if (todayPageMode ?? .first) == .first
                    {
                        todayPageMode = .second
                    }
                    else
                    {
                        todayPageMode = .first
                    }
                }
            }
        }
        label:
        {
            Image(systemName: !isTodaySelected ? "arrow.turn.down.left" : (todayPageMode ?? .first) == .first ? "sun.min.fill" : "moon.stars.fill")
                .foregroundColor(Color("TextColor"))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30)
                .fontWeight(.medium)
        }
        .disabled(AppSettings.showWelcome || !AppSettings.isSettingsInputValid)
    }
}

#Preview { PreviewPager }

var PreviewPager: some View
{
    NavigationView
    {
        ZStack
        {
            Settings.shared.AppBackground
                .ignoresSafeArea(.all)
            
            Pager(lb: 5, tb: 1)
        }
    }
    .environmentObject(Settings.shared)
    .environment(WeightDataViewModel())
    .environment(Streak())
}
