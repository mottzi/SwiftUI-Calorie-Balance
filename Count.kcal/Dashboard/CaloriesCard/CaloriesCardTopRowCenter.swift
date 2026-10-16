import SwiftUI

/// Balance amount and goal status inside the selected circular graph.
struct CaloriesCardTopRowCenter: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @EnvironmentObject private var AppSettings: Settings

    @Environment(HealthInterface.self) private var DataViewModel

    let mode: GraphMode
    var isLoading = false
    var showsDetails = true
    
    var body: some View {
        ZStack {
            CircleBalanceGraph(mode: mode)
                .frame(width: 130, height: 130)
                .opacity(isLoading ? 0.2 : 1)

            VStack(spacing: 0) {
                Text(verbatim: isLoading ? "500" : abs(balance).formatted(.number))
                    .redacted(reason: isLoading ? .placeholder : [])
                    .font(.system(size: 26))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(energy.isEmpty ? "SecondaryTextColor" : "TextColor"))
                    .contentTransition(.numericText(value: Double(abs(balance))))
                
                Text(isLoading ? "Balance" : balanceLabel)
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .contentTransition(.opacity)
                    .offset(y: -2)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
            }
            .fontDesign(.rounded)
            .opacity(showsDetails ? 1 : 0)
        
            if showsDetails && !isLoading && !AppSettings.hideCalorieStatusIcons && !energy.isEmpty {
                Image(systemName: goalReached ? "checkmark" : "xmark")
                    .font(.system(size: 12))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("SecondaryTextColor"))
                    .offset(y: 40)
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            }
        }
    }

}

extension CaloriesCardTopRowCenter {

    private var energy: EnergyBalance {
        mode == .now ? DataViewModel.sample.now : DataViewModel.sample.midnight
    }

    private var balance: Int { energy.balance }

    private var balanceLabel: LocalizedStringKey {
        if energy.isEmpty { return "Balance" }
        if balance > 0 { return "Deficit" }
        if balance < 0 { return "Surplus" }
        return ""
    }

    private var goalReached: Bool {
        energy.meetsGoal(
            AppSettings.balanceGoal,
            isLoss: AppSettings.weightGoal == .lose
        )
    }

}

#Preview { PreviewPager }
