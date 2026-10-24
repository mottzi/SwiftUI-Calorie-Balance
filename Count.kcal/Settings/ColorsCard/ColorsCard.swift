import SwiftUI

struct ColorsCard: View {

    @EnvironmentObject private var settings: Settings

    @Environment(\.colorScheme) private var scheme: ColorScheme

    var body: some View {
        Card("Colors") {
            VStack(spacing: 8) {
                if scheme == .dark {
                    BackgroundColorSection(selection: $settings.appBackground)
                }

                CalorieColorSection()
                ThemesSection()
            }
            .padding(.horizontal, 8)
        }
    }

}
