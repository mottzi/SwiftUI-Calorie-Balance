import SwiftUI

/// Balance amount and goal status inside the selected circular graph.
struct CaloriesCardTopRowCenter: View {

    @EnvironmentObject private var AppSettings: Settings

    @Environment(HealthInterface.self) private var DataViewModel

    let mode: GraphMode
    
    var body: some View {
        ZStack {
            CircleBalanceGraph(mode: mode)
                .frame(width: 130, height: 130)

            VStack(spacing: 0) {
                Text("\(abs(balance))")
                    .font(.system(size: 26))
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextColor"))
                    .contentTransition(.numericText(value: Double(abs(balance))))
                
                Text(balance > 0
                    ? String(localized: "Deficit")
                    : balance == 0 ? String("") : String(localized: "Surplus"))
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .offset(y: -2)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
            }
            .fontDesign(.rounded)
        
            Image(systemName: goalReached ? "checkmark" : "xmark")
                .font(.system(size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color("SecondaryTextColor"))
                .offset(y: 40)
                .transaction { $0.animation = .none }
        }
    }

}

extension CaloriesCardTopRowCenter {

    private var energy: EnergyBalance {
        mode == .now ? DataViewModel.sample.now : DataViewModel.sample.midnight
    }

    private var balance: Int { energy.balance }

    private var goalReached: Bool {
        energy.meetsGoal(
            AppSettings.balanceGoal,
            isLoss: AppSettings.weightGoal == .lose
        )
    }

}

#Preview {
    NavigationView {
        ZStack {
            Settings.shared.AppBackground.ignoresSafeArea(.all)
            
            Pager(lb: 6, tb: 1)
                .environmentObject(Settings.shared)
                .environment(WeightHistory())
        }
    }
}
