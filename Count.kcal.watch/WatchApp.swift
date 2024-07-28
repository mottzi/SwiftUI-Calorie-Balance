import SwiftUI

@main
struct WatchApp: App 
{
    @StateObject private var AppSettings = Settings.shared
    @StateObject private var Watch = Connectivity.shared

    var body: some Scene
    {
        WindowGroup
        {
            ContentView(Interface: HealthInterface(.empty(for: .now)))
                .environmentObject(AppSettings)
        }
    }
}

#Preview
{
    ContentView(Interface: HealthInterface(.example(for: .now, balance: .surplus)))
        .environmentObject(Settings.shared)
}
