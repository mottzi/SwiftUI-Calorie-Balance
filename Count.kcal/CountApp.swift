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
            #if DEBUG && targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--weight-chart-qa") {
                WeightChartGallery()
            } else {
                dashboard
            }
            #else
            dashboard
            #endif
        }
    }

    private var dashboard: some View {
        DatabaseGate {
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
