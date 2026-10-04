import SwiftUI

struct SettingsToolbarButton: View {

    @Binding var showSettings: Bool

    var body: some View {
        Button(action: openSettings) {
            Image(systemName: "gear")
                .foregroundStyle(Color("TextColor"))
                .fontWeight(.medium)
        }
    }

    private func openSettings() {
        showSettings = true
    }

}
