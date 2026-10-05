import SwiftUI

struct BackgroundColorSection: View {

    @Environment(\.dynamicTypeSize) private var dynamicType

    @EnvironmentObject private var settings: Settings

    var body: some View {
        let layout = dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top))
        layout {
            Text("Background")
                .font(.subheadline)
                .fontWeight(.semibold)

            if !dynamicType.isAccessibilitySize { Spacer() }

            HStack(spacing: 24) {
                BackgroundOption(
                    selection: $settings.appBackground,
                    title: "Black",
                    color: .black,
                    value: .black
                )
                BackgroundOption(
                    selection: $settings.appBackground,
                    title: "Dark",
                    color: Color("BackGroundColor"),
                    value: .dark
                )
                BackgroundOption(
                    selection: $settings.appBackground,
                    title: "Gray",
                    color: Color(white: 0.1),
                    value: .light
                )
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .sensoryFeedback(.selection, trigger: settings.appBackground)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.top, 6)

        Divider()
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
