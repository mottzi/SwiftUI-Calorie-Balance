import SwiftUI

struct CircleBalanceGraphOverlay: View {

    var balance: Int
    var isSampleData = false
    var isMarketingMode = false
    
    var body: some View {
        VStack(spacing: 0) {
            Text("\(abs(balance))")
                .font(.title2)
                .fontWeight(.semibold)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .contentTransition(.numericText(value: Double(abs(balance))))
            
            Text(balance > 0 ? String(localized: "Deficit") : balance == 0 ? String("") : String(localized: "Surplus"))
                .font(.caption)
                .fontWeight(.regular)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .opacity(0.8)
                .offset(y: -4)
        }
        .overlay(alignment: .bottom) {
            if isSampleData && !isMarketingMode {
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
}
