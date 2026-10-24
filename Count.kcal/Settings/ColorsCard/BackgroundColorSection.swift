import SwiftUI

struct BackgroundColorSection: View {

    @Environment(\.dynamicTypeSize) private var dynamicType

    @Binding var selection: Settings.AppBackgrounds
    var showsDivider = true
    var showsTitle = true
    var color: KeyPath<Settings.AppBackgrounds, Color> = \.swatchColor

    var body: some View {
        let layout = dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top))
        layout {
            if showsTitle {
                Text("Background")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if !dynamicType.isAccessibilitySize { Spacer() }
            }

            HStack(spacing: 24) {
                BackgroundOption(
                    selection: $selection,
                    title: "Black",
                    color: Settings.AppBackgrounds.black[keyPath: color],
                    value: .black
                )
                BackgroundOption(
                    selection: $selection,
                    title: "Dark",
                    color: Settings.AppBackgrounds.dark[keyPath: color],
                    value: .dark
                )
                BackgroundOption(
                    selection: $selection,
                    title: "Gray",
                    color: Settings.AppBackgrounds.light[keyPath: color],
                    value: .light
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .sensoryFeedback(.selection, trigger: selection)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.top, 6)

        if showsDivider { Divider() }
    }

}

/// A native button gives each background choice keyboard and accessibility support.
private struct BackgroundOption: View {

    @Binding var selection: Settings.AppBackgrounds

    let title: LocalizedStringKey
    let color: Color
    let value: Settings.AppBackgrounds

    var body: some View {
        Button(action: select) {
            VStack(spacing: 8) {
                Circle()
                    .stroke(Color(white: selection == value ? 0.7 : 0.22), lineWidth: 6)
                    .fill(color)
                    .frame(width: 24, height: 24)
                    .overlay {
                        if selection == value {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .accessibilityHidden(true)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color("TextColor"))
                    .opacity(selection == value ? 1 : 0.6)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == value ? .isSelected : [])
    }

}

extension BackgroundOption {

    private func select() {
        withAnimation { selection = value }
    }

}

#Preview {
    NavigationStack {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
