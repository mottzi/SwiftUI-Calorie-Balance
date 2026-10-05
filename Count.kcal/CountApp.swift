import SwiftUI

@main
/// Main app scene with shared settings, health pages, and streak state.
struct CountApp: App {

    @StateObject private var AppSettings = Settings.shared

    @State private var weightHistory = WeightHistory()
    @State private var StreakManager = Streak()

    init() { HealthDataMode.shared.configureLaunchArguments() }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ZStack {
                    AppSettings.AppBackground
                        .ignoresSafeArea(.all)

                    Pager(lb: 5, tb: 1)
                        .environmentObject(AppSettings)
                        .environment(weightHistory)
                        .environment(StreakManager)
                }
                #if DEBUG && targetEnvironment(simulator)
                .task { await SimulatorHealthSeeder.runIfRequested() }
                #endif
                #if os(iOS)
                .modifier(SettingsContextSync(weightHistory: weightHistory))
                #endif
            }
        }
    }

}

#Preview { PreviewPager }
