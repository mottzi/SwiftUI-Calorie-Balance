import SwiftUI

struct CaloriesTab: View {

    @EnvironmentObject private var AppSettings: Settings

    @Environment(HealthInterface.self) private var Interface
    
    let mode: GraphMode
    let toggleMode: () -> Void
    
    var body: some View {
        VStack {
            Button(action: toggleMode) {
                CircleBalanceGraphWatch(mode: mode)
                    .overlay { CircleBalanceGraphOverlay(balance: balance, isSampleData: Interface.sample.isSampleData) }
            }
            .buttonStyle(.plain)
            .accessibilityHint(mode == .now ? "Midnight" : "Now")
            
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

extension CaloriesTab {

    var bgColor: Color {
        balance >= 0 ? AppSettings.burnedColor : AppSettings.consumedColor
    }

}

extension CaloriesTab {

    private var balance: Int {
        mode == .now ? Interface.sample.balanceNow : Interface.sample.balanceMidnight
    }

}

#Preview {
    ContentView(Interface: HealthInterface(.example(for: .now, balance: .deficit)))
        .environmentObject(Settings.shared)
}
