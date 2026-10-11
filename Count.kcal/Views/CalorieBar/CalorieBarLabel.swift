import SwiftUI

/// A complete calorie value with the existing bar label appearance.
struct CalorieBarLabel: View {

    @Environment(\.colorScheme) private var scheme

    let value: Int
    let animatesNumericValues: Bool

    var body: some View {
        Text("\(value)")
            .foregroundStyle(Color("GraphTextColor"))
            .font(.caption)
            .fontDesign(.rounded)
            .fontWeight(.semibold)
            .contentTransition(animatesNumericValues ? .numericText(value: Double(value)) : .identity)
            .fixedSize()
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .trailing
            )
            .clipped()
            .shadow(color: .black.opacity(scheme == .dark ? 0.8 : 0.5), radius: 4)
            .contrast(scheme == .dark ? 1.5 : 2)
            .opacity(value > 0 ? 1 : 0)
            .accessibilityHidden(value == 0)
    }

}
