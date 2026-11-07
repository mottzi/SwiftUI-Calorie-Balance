import SwiftUI
import WidgetKit

/// Watch dashboard with a shared daily snapshot and calorie display mode.
struct ContentView: View {

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var Watch = Connectivity.shared
    @Environment(WatchSharingStore.self) private var sharing
    @State private var Interface: HealthInterface
    @State private var weightHistory = WeightHistory()

    @State private var healthDataMode = HealthDataMode.shared
    @State private var refreshRevision = 0
    @State private var healthAccessRequested = false
    @State private var tabSelection: WatchTab = .calories
    @State private var modeSelection: GraphMode = .now

    @Namespace private var balanceNamespace

    init(Interface: HealthInterface) {
        _Interface = State(initialValue: Interface)
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $tabSelection) {
                CaloriesTab(
                    mode: modeSelection,
                    toggleMode: toggleMode,
                    balanceNamespace: balanceNamespace,
                    balanceInToolbar: tabSelection == .macros
                )
                    .sensoryFeedback(.selection, trigger: modeSelection)
                    .tag(WatchTab.calories)

                MacrosTab(mode: modeSelection)
                    .tag(WatchTab.macros)

                WeightTab()
                    .tag(WatchTab.weight)
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    NavigationLink {
                        WatchSharingView()
                    } label: {
                        Label("Sharing", systemImage: "person.2.fill")
                    }
                }
                if tabSelection != .weight {
                    // Render the moving graph here so page blur doesn't duplicate it.
                    ToolbarItem(placement: .topBarLeading) {
                        CircleBalanceGraphWatch(mode: modeSelection)
                            .matchedGeometryEffect(
                                id: "balance",
                                in: balanceNamespace,
                                properties: reduceMotion ? [] : .frame,
                                isSource: tabSelection == .macros
                            )
                            .frame(width: 28, height: 28)
                            .opacity(!reduceMotion || tabSelection == .macros ? 1 : 0)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
            }
            .opacity(Interface.sample.isUnavailable && tabSelection != .weight ? 0 : 1)
            .accessibilityHidden(Interface.sample.isUnavailable && tabSelection != .weight)
            .overlay {
                if Interface.sample.isUnavailable, tabSelection != .weight {
                    Text("Health data unavailable")
                        .font(.caption)
                        .padding()
                        .background(.background, in: .rect(cornerRadius: 12))
                }
            }
            .tabViewStyle(.verticalPage)
            .toolbar(tabSelection == .weight ? .hidden : .visible, for: .navigationBar)
            .task(id: healthDataMode.usesSampleData) {
                healthAccessRequested = false
                weightHistory.reset()
                // Sample reads bypass authorization; returning to HealthKit requests access.
                _ = await HealthRepository.shared.requestPermission()
                guard !Task.isCancelled else { return }
                healthAccessRequested = true
                refreshRevision += 1
            }
            .task(id: refreshRevision) {
                guard scenePhase == .active, healthAccessRequested else { return }
                async let metrics: Void = Interface.updateMetrics()
                async let weight: Void = weightHistory.fetchData(
                    supplement: healthDataMode.usesSampleData ? nil : Watch.receivedWeightHistory
                )
                _ = await (metrics, weight)
            }
            .task(id: scenePhase == .active && healthAccessRequested && !healthDataMode.usesSampleData) {
                guard scenePhase == .active, healthAccessRequested, !healthDataMode.usesSampleData else { return }
                for await _ in HealthRepository.shared.weightChanges() {
                    guard !Task.isCancelled else { return }
                    refreshRevision += 1
                }
            }
            .onChange(of: Watch.lastReceivedSettingsContext, initial: true) { _, newValue in
                guard newValue != nil else { return }
                refreshRevision += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                updateDay()
                refreshRevision += 1
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // cancel the previous refresh whenever the scene changes phase
                refreshRevision += 1
                if newPhase == .active {
                    updateDay()
                } else if oldPhase == .active && newPhase == .inactive {
                    // make sure that the next timeline reload fetches live data
                    
                    // force timeline reload
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
        .environment(Interface)
        .environment(weightHistory)
        .modifier(WatchSharingReceiver(store: sharing, connectivity: Watch))
    }

}

extension ContentView {

    private func toggleMode() {
        withAnimation(reduceMotion ? nil : .bouncy(duration: 0.6)) {
            modeSelection = modeSelection == .now ? .midnight : .now
        }
    }

    /// Replaces the daily model after the calendar day changes.
    private func updateDay() {
        if Interface.id != Calendar.current.startOfDay(for: .now) {
            Interface = HealthInterface(.empty(for: .now))
        }
    }

}

/// Observes nutrition only inside the macro page, rather than the navigation container.
private struct MacrosTab: View {

    @EnvironmentObject private var settings: Settings

    @Environment(HealthInterface.self) private var health

    let mode: GraphMode

    var body: some View {
        VStack(spacing: 24) {
            ReachableView(
                "Carbs",
                consumedValue: health.sample.carbs,
                goalValue: settings.carbsGoal,
                color: settings.consumedColor,
                graphHeight: 10
            )

            ReachableView(
                "Fats",
                consumedValue: health.sample.fats,
                goalValue: settings.fatsGoal,
                color: settings.consumedColor,
                graphHeight: 10
            )

            ReachableView(
                "Protein",
                consumedValue: health.sample.protein,
                goalValue: settings.proteinGoal,
                color: settings.consumedColor,
                graphHeight: 10
            )
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        .padding(.top, 10)
        .scenePadding()
        .containerBackground(background.brighten(-0.3).gradient, for: .tabView)
    }

}

extension MacrosTab {

    private var background: Color {
        let balance = mode == .now ? health.sample.balanceNow : health.sample.balanceMidnight
        return balance >= 0 ? settings.burnedColor : settings.consumedColor
    }

}

private enum WatchTab {
    case calories
    case macros
    case weight
}

#Preview {
    ContentView(Interface: HealthInterface(.example(for: .now, balance: .deficit)))
        .environmentObject(Settings.shared)
        .environment(WatchSharingStore())
}
