import SwiftUI

struct ThemesSection: View {

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Themes")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)

                Spacer()
            }
            .padding(.vertical, 6)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                ForEach(Settings.Themes) { theme in
                    ThemeButton(theme: theme)
                }
            }
            .transition(.move(edge: .trailing))
            .saturation(Settings.baseSaturation)
            .brightness(level: .primary)
            .padding()
        }
    }

}

#Preview {
    NavigationView {
        SettingsPage()
            .environmentObject(Settings.shared)
    }
}
