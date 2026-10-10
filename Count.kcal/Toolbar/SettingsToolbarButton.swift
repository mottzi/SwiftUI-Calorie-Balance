import SwiftUI

struct SettingsToolbarButton: View {

    @Binding var showSettings: Bool

    var body: some View {
        Button(action: openSettings) {
            Image(systemName: "gearshape.fill")
                .foregroundStyle(Color("TextColor"))
                .fontWeight(.medium)
        }
        .accessibilityLabel("Settings")
    }

}

extension SettingsToolbarButton {

    private func openSettings() {
        showSettings = true
    }

}
