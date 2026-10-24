import SwiftUI
import WidgetKit

/// A complete calorie value with the existing bar label appearance.
struct CalorieBarLabel: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    let value: Int
    let animatesNumericValues: Bool
    var reservesSpace = true
    var usesContrastBackground = false
    var backgroundColor: Color = .black

    var body: some View {
        Text("\(value)")
            .foregroundStyle(usesContrastBackground ? Color.white : Color("GraphTextColor"))
            .font(.caption)
            .fontDesign(.rounded)
            .fontWeight(.semibold)
            .contentTransition(animatesNumericValues ? .numericText(value: Double(value)) : .identity)
            .fixedSize()
            .padding(.horizontal, usesContrastBackground ? 2 : 0)
            .background {
                if usesContrastBackground {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(backgroundColor)
                }
            }
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .trailing
            )
            .clipped()
            .shadow(color: renderingMode == .accented ? .clear : .black.opacity(scheme == .dark ? 0.8 : 0.5), radius: usesContrastBackground ? 0 : 4)
            .contrast(usesContrastBackground ? 1 : (scheme == .dark ? 1.5 : 2))
            .opacity(value > 0 ? 1 : 0)
            .accessibilityHidden(value == 0)
            .layoutValue(key: PresenceKey.self, value: reservesSpace && value > 0)
    }

    /// Hidden target values must not reserve space as spring geometry crosses zero.
    struct PresenceKey: LayoutValueKey {
        static let defaultValue = false
    }

}
