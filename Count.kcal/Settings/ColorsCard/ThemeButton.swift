import SwiftUI

struct ThemeButton: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @EnvironmentObject private var AppSettings: Settings

    @State private var wasTapped: Bool = false

    let theme: Settings.Theme
    let number: Int

    var body: some View {
        Button(action: selectTheme) {
            VStack(spacing: 2) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 10
                )
                    .fill(theme.burned)
                    .frame(width: 60, height: 18)
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 10,
                    bottomTrailingRadius: 10,
                    topTrailingRadius: 0
                )
                    .fill(theme.consumed)
                    .frame(width: 60, height: 18)
            }
                .scaleEffect(wasTapped ? 0.8 : 1)
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Theme \(number)", comment: "Numbered color theme button in Settings."))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: AppSettings.burnedColor)
    }

}

extension ThemeButton {

    private func selectTheme() {

        AppSettings.burnedColor = theme.burned
        AppSettings.consumedColor = theme.consumed
        guard !reduceMotion else { return }
        withAnimation(.spring(duration: 0.15)) {
            wasTapped = true
        } completion: {
            withAnimation(.spring(duration: 0.15)) { wasTapped = false }
        }
    }

    private var isSelected: Bool {
        AppSettings.burnedColor == theme.burned && AppSettings.consumedColor == theme.consumed
    }

}
