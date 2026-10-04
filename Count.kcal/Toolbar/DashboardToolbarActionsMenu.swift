import SwiftUI

/// Keeps calendar and settings actions available at accessibility text sizes.
struct DashboardToolbarActionsMenu: View {

    @Binding var showSettings: Bool
    let toggleCalendar: () -> Void

    var body: some View {
        Menu {
            Button(action: toggleCalendar) {
                Label("Calendar", systemImage: "calendar")
            }

            Button(action: openSettings) {
                Label("Settings", systemImage: "gear")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(Color("TextColor"))
                .accessibilityLabel("Calendar and Settings")
        }
    }

    private func openSettings() {
        showSettings = true
    }

}
