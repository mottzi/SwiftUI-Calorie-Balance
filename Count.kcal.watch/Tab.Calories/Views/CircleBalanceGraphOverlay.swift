import SwiftUI

struct CircleBalanceGraphOverlay: View
{
    var balance: Int
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            Text("\(abs(balance))")
                .font(.title2)
                .fontWeight(.semibold)
                .contentTransition(.numericText(value: Double(abs(balance))))
            
            Text(balance > 0 ? String(localized: "Deficit") : balance == 0 ? String("") : String(localized: "Surplus"))
                .font(.caption)
                .fontWeight(.regular)
                .opacity(0.8)
                .offset(y: -4)
        }
        .fontDesign(.rounded)
        .offset(y: -2)
    }
}

#Preview
{
    ContentView(Interface: HealthInterface(.example(for: .now, balance: .deficit)))
        .environmentObject(Settings.shared)
}
