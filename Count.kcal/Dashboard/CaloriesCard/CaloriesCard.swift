import SwiftUI

/// Now or midnight calorie totals and balance for one day.
struct CaloriesCard: View {

    @Environment(\.dynamicTypeSize) private var dynamicType

    let mode: GraphMode

    let sizeMapping: [DynamicTypeSize: CGFloat] = 
    [
        .xSmall: 44,
        .small: 44,
        .medium: 44,
        .large: 44,
        .xLarge: 46,
        .xxLarge: 48,
        .xxxLarge: 50,
        .accessibility1: 52,
        .accessibility2: 54,
        .accessibility3: 56,
        .accessibility4: 58,
        .accessibility5: 60,
    ]
    
    var body: some View {
        VStack(spacing: mode == .now && dynamicType > .xxxLarge ? 8 : 0) {
            CaloriesCardTopRow(mode: mode)
                .padding(.top, 2)

            BarBalanceGraph(mode: mode)
                .frame(height: sizeMapping[dynamicType, default: 44])
                .padding(.top, 6)
                .padding(.bottom, 2)
                .padding(.horizontal, 13)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
    }

}

#Preview {
    NavigationView {
        ZStack {
            Settings.shared.AppBackground.ignoresSafeArea(.all)
            
            Pager(lb: 6, tb: 1)
                .environmentObject(Settings.shared)
                .environment(WeightDataViewModel())
        }
    }
}
