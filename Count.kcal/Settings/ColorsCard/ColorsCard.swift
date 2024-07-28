import SwiftUI

struct ColorsCard: View
{
    @Environment(\.colorScheme) private var scheme: ColorScheme

    var body: some View
    {
        Card("Colors", titlePadding: false)
        {
            VStack(spacing: 8)
            {
                if scheme == .dark
                {
                    BackgroundColorSection()
                }

                CalorieColorSection()
                ThemesSection()
            }
            .padding(.horizontal, 8)
        }
    }
}
