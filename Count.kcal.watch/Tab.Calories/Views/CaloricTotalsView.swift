import SwiftUI

struct CaloricTotalsView: View {

    let burned: Int
    let consumed: Int
    let burnedColor: Color
    let consumedColor: Color
    var unit: String? = nil
    
    var body: some View {
        HStack {
            Spacer(minLength: 0)
            
            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 16)
                        .fontWeight(.black)
                        .foregroundStyle(burnedColor.brighten(0.3).gradient)
                    
                    Text(burned, format: .number)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary.opacity(0.75))
                        .contentTransition(.numericText(value: Double(burned)))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Burned")
                .accessibilityValue(Text("\(burned) \(unit ?? "")"))
                
                Circle()
                    .fill(.primary)
                    .frame(width: 5)
                    .frame(width: 10, height: 10)
                
                HStack(spacing: 3) {
                    Text(consumed, format: .number)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary.opacity(0.75))
                        .contentTransition(.numericText(value: Double(consumed)))
                    
                    Image(systemName: "fork.knife")
                        .resizable()
                        .fontWeight(.black)
                        .scaledToFit()
                        .frame(height: 16)
                        .foregroundStyle(consumedColor.brighten(0.3).gradient)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Eaten")
                .accessibilityValue(Text("\(consumed) \(unit ?? "")"))
            }
            .padding(4)
            .padding(.horizontal, 8)
            .background(in: .capsule)
            .backgroundStyle(.tertiary.opacity(0.8))
            
            Spacer(minLength: 0)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

}

#Preview {
    ContentView(Interface: HealthInterface(.example(for: .now, balance: .deficit)))
        .environmentObject(Settings.shared)
}
