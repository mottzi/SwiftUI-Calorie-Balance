import SwiftUI

struct CaloriesTab: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) var Interface
    
    let mode: GraphMode
    let balance: Int
    let toggleMode: () -> Void
    
    var bgColor: Color
    {
        balance >= 0 ? AppSettings.burnedColor : AppSettings.consumedColor
    }
    
    var body: some View
    {
        VStack
        {
            Button 
            {
                #if !DEBUG
                toggleMode()
                #else
                withAnimation(.snappy)
                {
                    Interface.randomizeHealthData()
                }
                #endif
            }
            label:
            {
                CircleBalanceGraphWatch(mode: mode)
                    .overlay { CircleBalanceGraphOverlay(balance: balance) }
            }
            .buttonStyle(.plain)
            
            CaloricTotalsView(mode: mode)
                .offset(y: 10)
        }
        .compositingGroup()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .containerBackground(bgColor.brighten(-0.3).gradient, for: .tabView)
        .padding(.top, 18)
        .scenePadding(.horizontal)
    }
}

#Preview
{
    ContentView(Interface: HealthInterface(.example(for: .now, balance: .deficit)))
        .environmentObject(Settings.shared)
}
