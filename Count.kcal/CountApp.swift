import SwiftUI

@main
struct CountApp: App
{
    @StateObject private var AppSettings = Settings.shared
    @StateObject private var Watch = Connectivity.shared

    @State private var WeightViewModel = WeightDataViewModel()
    @State private var StreakManager = Streak()

    var body: some Scene
    {
        WindowGroup
        {
            NavigationStack
            {
                ZStack
                {
                    AppSettings.AppBackground
                        .ignoresSafeArea(.all)

                    Pager(lb: 5, tb: 1)
                        .environmentObject(AppSettings)
                        .environment(WeightViewModel)
                        .environment(StreakManager)
                }
            }
        }
    }
}

#Preview
{    
    NavigationStack
    {
        ZStack
        {
            Settings.shared.AppBackground
                .ignoresSafeArea(.all)
            
            Pager(lb: 5, tb: 1)
                .environmentObject(Settings.shared)
                .environment(WeightDataViewModel())
                .environment(Streak())
        }
    }
}
