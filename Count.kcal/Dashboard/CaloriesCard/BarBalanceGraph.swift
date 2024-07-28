import SwiftUI

struct BarBalanceGraph: View
{
    @Environment(\.colorScheme) private var scheme: ColorScheme
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel

    var context: ViewContext = .app
    var labels = true
    
    var body: some View
    {
        GeometryReader
        { container in
            VStack(spacing: scheme == .light ? 1 : 2)
            {
                GeometryReader
                { geometry in
                    BarBalanceGraphTopRow(geometry: geometry, context: context, labels: labels)
                }
                .frame(height: container.size.height / 2 - 1)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 6, style: .continuous))
                
                GeometryReader
                { geometry in
                    BarBalanceGraphBottomRow(geometry: geometry, context: context, labels: labels)
                }
                .frame(height: container.size.height / 2 - 1)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 0, style: .continuous))
            }
            .saturation(Settings.baseSaturation)
        }
    }
}

#Preview
{
    BarBalanceGraph()
        .environment(HealthInterface(.example(for: .now, balance: .deficit)))
        .environmentObject(Settings.shared)
        .frame(height: 44)
        .padding(.trailing, 80)
        .padding(.leading, 30)
        .fontDesign(.rounded)
}

#Preview
{
    NavigationView
    {
        ZStack
        {
            Settings.shared.AppBackground.ignoresSafeArea(.all)
            
            Pager(lb: 6, tb: 1)
                .environment(Streak())
                .environmentObject(Settings.shared)
                .environment(WeightDataViewModel())
        }
    }
}
