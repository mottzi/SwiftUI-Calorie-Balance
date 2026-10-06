import SwiftUI

/// Keeps a trailing segment's value readable even when the segment is narrow.
struct BarBalanceGraphEndLabel: View {

    @Environment(\.colorScheme) private var scheme

    let value: Int
    let width: CGFloat
    let animateNumericValues: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text("\(value)")
                .graphLabelStyle(scheme)
                .fixedSize()
                .padding(.horizontal, 4)

            // Extend into the preceding segment, keeping the value inside the bar.
            Text("\(value)")
                .graphLabelStyle(scheme)
                .fixedSize()
                .padding(.trailing, 4)
                .frame(width: width, alignment: .trailing)
        }
        .contentTransition(animateNumericValues ? .numericText(value: Double(value)) : .identity)
        .frame(width: width)
    }
}
