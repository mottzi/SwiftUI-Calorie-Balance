import SwiftUI
import UIKit

@main
/// Main app scene for settings, health pages, streak state, and sharing lifecycle.
struct CountApp: App {

    /// Receives CloudKit invitations and background sharing notifications.
    @UIApplicationDelegateAdaptor(SharingAppDelegate.self) private var sharingDelegate

    @StateObject private var AppSettings = Settings.shared

    @State private var weightHistory = WeightHistory()
    @State private var StreakManager = Streak()

    /// Configures launch data and starts the Debug sharing validation listener.
    init() {
        Self.configureRoundedControlFonts()
        HealthDataMode.shared.configureLaunchArguments()
        #if DEBUG
        CloudSharingValidation.startIfRequested()
        #endif
    }

    /// Selects the dashboard or a Debug simulator fixture at launch.
    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG && targetEnvironment(simulator)
                if NSClassFromString("XCTestCase") != nil {
                    // Hosted unit tests supply their own databases and runtimes.
                    Color.clear
                } else if ProcessInfo.processInfo.arguments.contains("--sharing-qa") {
                    NavigationStack { SharingOverviewView(runtime: .shared) }
                        .sheet(isPresented: Binding(
                            get: { SharingRuntime.shared.receivedInvitationID != nil },
                            set: { if !$0 { SharingRuntime.shared.receivedInvitationID = nil } }
                        )) {
                            SharingReceivedInvitationView(runtime: .shared)
                        }
                        .environmentObject(AppSettings)
                } else if ProcessInfo.processInfo.arguments.contains("--weight-chart-qa") {
                    WeightChartGallery()
                } else {
                    dashboard
                }
                #else
                dashboard
                #endif
            }
            .fontDesign(.rounded)
        }
    }

    /// Native navigation titles and segmented controls use their own font defaults.
    private static func configureRoundedControlFonts() {
        let navigationBar = UINavigationBar.appearance()
        let titleDescriptor = UIFont.preferredFont(forTextStyle: .headline).fontDescriptor
        let largeTitleDescriptor = UIFont.preferredFont(forTextStyle: .largeTitle).fontDescriptor
        let boldLargeTitleDescriptor = largeTitleDescriptor.withSymbolicTraits(.traitBold) ?? largeTitleDescriptor

        navigationBar.titleTextAttributes = [
            .font: UIFont(descriptor: titleDescriptor.withDesign(.rounded) ?? titleDescriptor, size: 0)
        ]
        navigationBar.largeTitleTextAttributes = [
            .font: UIFont(descriptor: boldLargeTitleDescriptor.withDesign(.rounded) ?? boldLargeTitleDescriptor, size: 0)
        ]

        let segmentedControl = UISegmentedControl.appearance()
        let segmentStates: [(UIControl.State, UIFont.Weight)] = [(.normal, .regular), (.selected, .medium)]
        for (state, weight) in segmentStates {
            let descriptor = UIFont.systemFont(ofSize: 13, weight: weight).fontDescriptor
            segmentedControl.setTitleTextAttributes([
                .font: UIFont(descriptor: descriptor.withDesign(.rounded) ?? descriptor, size: 0)
            ], for: state)
        }
    }

    /// Builds the dashboard and attaches app-scene sharing lifecycle work.
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
            .modifier(SharingLifecycleModifier(runtime: .shared))
            .environmentObject(AppSettings)
        }
    }

}

#Preview { PreviewPager }
