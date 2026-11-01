import SwiftUI

/// Balance amount and goal status inside the selected circular graph.
struct CaloriesCardTopRowCenter: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Energy totals for the selected calorie card.
    let energy: EnergyBalance

    /// Burned-energy graph color for the selected appearance.
    let burnedColor: Color

    /// Eaten-energy graph color for the selected appearance.
    let consumedColor: Color

    /// Empty graph color for the selected appearance.
    let graphEmptyColor: Color

    /// Goal result shown in the center when the dashboard exposes one.
    let visibleGoalReached: Bool?
    var isLoading = false
    
    var body: some View {
        ZStack {
            CalorieCircleGraph(
                energy: energy,
                palette: CalorieGraphPalette(burned: burnedColor, consumed: consumedColor, empty: graphEmptyColor)
            )
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
        
            if !isLoading, let goalReached = visibleGoalReached, !energy.isEmpty {
                Image(systemName: goalReached ? "checkmark" : "xmark")
                    .font(.system(size: 12))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("SecondaryTextColor"))
                    .offset(y: 40)
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                    .accessibilityLabel(goalReached ? Text("Goal reached") : Text("Goal not reached"))
            }
        }
    }

}

extension CaloriesCardTopRowCenter {

    private var balance: Int { energy.balance }

    private var balanceLabel: LocalizedStringKey {
        if energy.isEmpty { return "Balance" }
        if balance > 0 { return "Deficit" }
        if balance < 0 { return "Surplus" }
        return ""
    }

}

#Preview { PreviewPager }
