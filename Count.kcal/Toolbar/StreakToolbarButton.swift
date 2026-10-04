import SwiftUI

/// Toolbar control for the streak count and chart visibility.
struct StreakToolbarButton: View {

    let color: Color
    let controlsDisabled: Bool

    @Environment(Streak.self) private var streak

    var body: some View {
        Button {
            streak.toggleStreaksView()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(color.brighten(-0.1).gradient)
                    .fontWeight(.bold)

                Text("\(streak.streaks)")
                    .font(.callout)
                    .fontDesign(.rounded)
                    .fontWeight(.bold)
                    .foregroundStyle(Color("TextColor"))
            }
        }
        .disabled(controlsDisabled)
    }

}
