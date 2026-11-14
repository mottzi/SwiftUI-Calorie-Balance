import SwiftUI

@main
struct WatchApp: App {

    @StateObject private var AppSettings = Settings.shared
    @State private var sharing: WatchSharingStore

    init() {
        #if DEBUG
        let store = WatchSharingFixtures.isActive ? WatchSharingFixtures.makeStore() : WatchSharingStore()
        #else
        let store = WatchSharingStore()
        #endif
        _sharing = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(Interface: HealthInterface(.empty(for: .now)))
                .environmentObject(AppSettings)
                .environment(sharing)
                #if DEBUG
                .transformEnvironment(\.dynamicTypeSize) { size in
                    if WatchSharingFixtures.isActive {
                        let args = ProcessInfo.processInfo.arguments
                        if args.contains("--watch-sharing-large-text") { size = .xxxLarge }
                        if args.contains("--watch-sharing-accessibility-text") { size = .accessibility3 }
                    }
                }
                #endif
        }
    }

}

#Preview {
    ContentView(Interface: HealthInterface(.example(for: .now, balance: .surplus)))
        .environmentObject(Settings.shared)
        .environment(WatchSharingStore())
}
