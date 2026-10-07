import SwiftUI

/// Now or midnight calorie totals and balance for one day.
struct CaloriesCard: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var settings: Settings

    let mode: GraphMode
    var animateNumericValues = false

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
        VStack(spacing: dynamicType.isAccessibilitySize ? 8 : 0) {
            CaloriesCardTopRow(mode: mode)
                .padding(.top, 2)

            BarBalanceGraph(
                mode: mode,
                labels: !dynamicType.isAccessibilitySize,
                animateNumericValues: animateNumericValues
            )
                .frame(height: sizeMapping[dynamicType, default: 44])
                .padding(.top, 6)
                .padding(.bottom, 2)
                .padding(.horizontal, 13)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(settings.CardBackground)
        .clipShape(.rect(cornerRadius: 10))
    }

}

#Preview { PreviewPager }
