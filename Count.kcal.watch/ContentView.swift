import SwiftUI
import WidgetKit

struct ContentView: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var ring
    
    @StateObject var Watch = Connectivity.shared
    @State var Interface: HealthInterface

    @State private var firstLaunch = Date.now
    @State private var tabSelection = 0
    @State private var modeSelection: GraphMode = .now
    
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
            .task { await Interface.updateMetrics() }
            .onChange(of: Watch.lastReceivedSettingsContext)
            { _, newValue in
                guard newValue != nil else { return }
                Task { await Interface.updateMetrics() }
            }
            .onChange(of: scenePhase)
            { oldPhase, newPhase in
                if newPhase == .active
                {
                    let now = Date.now

                    if !now.isSameDay(as: firstLaunch)
                    {
                        firstLaunch = now
                        Interface.sample.date = now
                    }
                    
                    Task.detached { await Interface.updateMetrics() }
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

#Preview
{
    ContentView(Interface: HealthInterface(.example(for: .now, balance: .deficit)))
        .environmentObject(Settings.shared)
}
