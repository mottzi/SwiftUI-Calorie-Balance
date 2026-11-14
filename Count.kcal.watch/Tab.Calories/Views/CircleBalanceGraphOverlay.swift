import SwiftUI

struct CircleBalanceGraphOverlay: View {

    var balance: Int
    var isSampleData = false
    var isMarketingMode = false
    var unit: String? = nil
    var goalReached: Bool? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            Text(abs(balance), format: .number)
                .font(.title2)
                .fontWeight(.semibold)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .contentTransition(.numericText(value: Double(abs(balance))))
            if let unit {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }

            Text(balance > 0 ? LocalizedStringResource("Deficit") : balance == 0 ? LocalizedStringResource("") : LocalizedStringResource("Surplus"))
                .font(.caption)
                .fontWeight(.regular)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .opacity(0.8)
                .offset(y: -4)
        }
        .overlay(alignment: .bottom) {
            if let goalReached {
                Image(systemName: goalReached ? "checkmark" : "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(goalReached ? "Goal reached" : "Goal not reached")
                    .offset(y: 20)
            } else if isSampleData && !isMarketingMode {
                Image(systemName: "testtube.2")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Sample Data")
                    .offset(y: 24)
            }
        }
        .fontDesign(.rounded)
        .offset(y: -2)
    }

}

#Preview {
    ContentView(Interface: HealthInterface(.example(for: .now, balance: .deficit)))
        .environmentObject(Settings.shared)
        .environment(WatchSharingStore())
}
