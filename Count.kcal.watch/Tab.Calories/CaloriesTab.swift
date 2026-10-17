import SwiftUI

struct CaloriesTab: View {

    @EnvironmentObject private var AppSettings: Settings

    @Environment(HealthInterface.self) private var Interface

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    let mode: GraphMode
    let toggleMode: () -> Void
    let balanceNamespace: Namespace.ID
    let balanceInToolbar: Bool
    
    var body: some View {
        VStack {
            Button(action: toggleMode) {
                CircleBalanceGraphWatch(mode: mode)
                    .matchedGeometryEffect(
                        id: "balance",
                        in: balanceNamespace,
                        properties: reduceMotion ? [] : .frame,
                        isSource: !balanceInToolbar
                    )
                    // Supply the large frame while the shared toolbar copy draws the graph.
                    .opacity(reduceMotion ? 1 : 0)
                    .overlay { CircleBalanceGraphOverlay(balance: balance, isSampleData: Interface.sample.isSampleData) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(mode == .now ? "Midnight" : "Now")
            
            CaloricTotalsView(mode: mode)
                .offset(y: 10)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .containerBackground(bgColor.brighten(-0.3).gradient, for: .tabView)
        .padding(.top, 18)
        .scenePadding(.horizontal)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleMode) {
                    Label(
                        mode == .now ? "Midnight" : "Now",
                        systemImage: mode == .now ? "sun.min.fill" : "moon.stars.fill"
                    )
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.white.opacity(0.9))
                    .contentTransition(.symbolEffect(.replace))
                }
            }
        }
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
