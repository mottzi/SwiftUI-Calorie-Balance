import SwiftUI

struct CaloricTotalsView: View
{
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) var Interface
    
    let mode: GraphMode
    
    var burnedTotal: Int
    {
        if mode == .now
        {
            Interface.sample.burnedActive + Interface.sample.burnedPassive
        }
        else
        {
            (AppSettings.dataSource == Settings.DataSources.custom ? Interface.sample.burnedActive7 : Interface.sample.burnedActive) + Interface.sample.burnedPassive + Interface.sample.burnedPassiveRemaining
        }
    }
    
    var body: some View
    {
        HStack
        {
            Spacer(minLength: 0)
            
            HStack
            {
                HStack(spacing: 3)
                {
                    Image(systemName: "bolt.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 16)
                        .fontWeight(.black)
                        .foregroundStyle(AppSettings.burnedColor.brighten(0.3).gradient)
                    
                    Text("\(burnedTotal)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary.opacity(0.75))
                        .contentTransition(.numericText(value: Double(burnedTotal)))
                }
                
                Circle()
                    .fill(.primary)
                    .frame(width: 5)
                    .frame(width: 10, height: 10)
                
                HStack(spacing: 3)
                {
                    Text("\(Interface.sample.consumed)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary.opacity(0.75))
                        .contentTransition(.numericText(value: Double(Interface.sample.consumed)))
                    
                    Image(systemName: "fork.knife")
                        .resizable()
                        .fontWeight(.black)
                        .scaledToFit()
                        .frame(height: 16)
                        .foregroundStyle(AppSettings.consumedColor.brighten(0.3).gradient)
                }
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

#Preview
{
    ContentView(Interface: HealthInterface(.example(for: .now, balance: .deficit)))
        .environmentObject(Settings.shared)
}
