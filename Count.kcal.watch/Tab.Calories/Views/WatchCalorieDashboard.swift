import SwiftUI

/// The watch dashboard's balance area and compact energy totals, for local or shared data.
struct WatchCalorieDashboard<Balance: View>: View {
    let burned: Int
    let consumed: Int
    let burnedColor: Color
    let consumedColor: Color
    var unit: String? = nil
    var totalsOffset: CGFloat = 10
    @ViewBuilder var balance: Balance

    var body: some View {
        VStack {
            balance
            CaloricTotalsView(
                burned: burned,
                consumed: consumed,
                burnedColor: burnedColor,
                consumedColor: consumedColor,
                unit: unit
            )
            .offset(y: totalsOffset)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}
