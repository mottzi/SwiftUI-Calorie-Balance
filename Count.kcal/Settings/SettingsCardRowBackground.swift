import SwiftUI

/// Draws card corners behind native rows, without clipping their drag previews.
struct SettingsCardRowBackground: View {
    @EnvironmentObject private var settings: Settings

    var roundsTop = false
    var roundsBottom = false

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: roundsTop ? CardMetrics.cornerRadius : 0,
            bottomLeadingRadius: roundsBottom ? CardMetrics.cornerRadius : 0,
            bottomTrailingRadius: roundsBottom ? CardMetrics.cornerRadius : 0,
            topTrailingRadius: roundsTop ? CardMetrics.cornerRadius : 0
        )
        .fill(settings.CardBackground)
    }
}
