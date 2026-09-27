import SwiftUI
import WidgetKit

/// Watch dashboard with a shared daily snapshot and calorie display mode.
struct ContentView: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var Watch = Connectivity.shared
    @State private var Interface: HealthInterface

    @State private var refreshRevision = 0
    @State private var healthAccessRequested = false
    @State private var tabSelection = 0
    @State private var modeSelection: GraphMode = .now

    init(Interface: HealthInterface)
    {
        _Interface = State(initialValue: Interface)
    }
    
    func toggleMode()
    {
        withAnimation(.bouncy(duration: 0.6))
        {
            modeSelection = modeSelection == .now ? .midnight : .now
        }
    }
    
    var calorieBalance: Int
    {
        modeSelection == .now ? Interface.sample.balanceNow : Interface.sample.balanceMidnight
    }
    
    var bgColor: Color
    {
        calorieBalance >= 0 ? AppSettings.burnedColor : AppSettings.consumedColor
    }
    
    var body: some View
    {
        NavigationStack
        {
            TabView(selection: $tabSelection)
            {
                CaloriesTab(mode: modeSelection, balance: calorieBalance, toggleMode: toggleMode)
                    .sensoryFeedback(.selection, trigger: modeSelection)
                    .tag(0)
                
                VStack(spacing: 24)
                {
                    ReachableView("Carbs", consumedValue: Interface.sample.carbs, goalValue: AppSettings.carbsGoal, color: AppSettings.consumedColor, graphHeight: 10)

                    ReachableView("Fats", consumedValue: Interface.sample.fats, goalValue: AppSettings.fatsGoal, color: AppSettings.consumedColor, graphHeight: 10)
                    
                    ReachableView("Protein", consumedValue: Interface.sample.protein, goalValue: AppSettings.proteinGoal, color: AppSettings.consumedColor, graphHeight: 10)
                }
                .dynamicTypeSize(...DynamicTypeSize.large)
                .padding(.top, 10)
                .scenePadding()
                .containerBackground(bgColor.brighten(-0.3).gradient, for: .tabView)
                .tag(1)
            }
            .toolbar
            {
                ToolbarItem(placement: .topBarLeading)
                {
                    CircleBalanceGraphWatch(mode: modeSelection)
                        .environment(Interface)
                        .offset(x: 2)
                        .scaleEffect(tabSelection == 0 ? 0.3 : 1)
                        .animation(.bouncy(extraBounce: 0.3), value: tabSelection)
                        .opacity(tabSelection == 0 ? 0 : 1)
                        .animation(.easeInOut, value: tabSelection)
                }
            
                ToolbarItem(placement: .topBarTrailing)
                {
                    Button
                    {
                        toggleMode()
                    }
                    label:
                    {
                        Image(systemName: modeSelection == .now ? "sun.min.fill" : "moon.stars.fill")
                            .foregroundStyle(.white.opacity(0.9))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .disabled(tabSelection != 0)
                    .blur(radius: tabSelection == 0 ? 0 : 4)
                    .opacity(tabSelection == 0 ? 1 : 0)
                    .scaleEffect(tabSelection == 0 ? 1 : 0.5)
                    .animation(.bouncy(extraBounce: 0.3), value: tabSelection)
                }
                
            }
            .tabViewStyle(.verticalPage)
            .task {
                // the watch has no onboarding flow, so request access before its first refresh
                _ = await HKRepository.shared.requestPermission()
                guard !Task.isCancelled else { return }
                healthAccessRequested = true
                refreshRevision += 1
            }
            .task(id: refreshRevision)
            {
                guard scenePhase == .active, healthAccessRequested else { return }
                await Interface.updateMetrics()
            }
            .onChange(of: Watch.lastReceivedSettingsContext)
            { _, newValue in
                guard newValue != nil else { return }
                refreshRevision += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                updateDay()
                refreshRevision += 1
            }
            .onChange(of: scenePhase)
            { oldPhase, newPhase in
                // cancel the previous refresh whenever the scene changes phase
                refreshRevision += 1
                if newPhase == .active
                {
                    updateDay()
                }
                else if oldPhase == .active && newPhase == .inactive
                {
                    // make sure that the next timeline reload fetches live data
                    // UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")!.set(Date(timeIntervalSinceReferenceDate: 0), forKey: "lastReceivedBalanceContext")
                    
                    // force timeline reload
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
        .environment(Interface)
    }
}

extension ContentView {

    /// Replaces the daily model after the calendar day changes.
    private func updateDay() {
        if Interface.id != Calendar.current.startOfDay(for: .now) {
            Interface = HealthInterface(.empty(for: .now))
        }
    }

}

#Preview
{
    ContentView(Interface: HealthInterface(.example(for: .now, balance: .deficit)))
        .environmentObject(Settings.shared)
}
