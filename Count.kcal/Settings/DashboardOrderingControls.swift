import SwiftUI

struct DashboardOrderingControls: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        Group {
            SettingsSection("Daily cards") {
                SettingsReorderRows(order: \.dailyCards, move: settings.moveDailyCards) { card in
                    Text(card.title)
                }
            }

            SettingsSection("Macros") {
                SettingsReorderRows(order: \.macros, move: settings.moveMacros) { macro in
                    Text(macro.title)
                }
            }

            SettingsSection("Progress") {
                Picker("Progress position", selection: $settings.dashboardProgressPosition) {
                    Text("Top").tag(ProgressPosition.above)
                    Text("Bottom").tag(ProgressPosition.below)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .environment(\.editMode, .constant(.inactive))
                .listRowInsets(EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10))
                .listRowBackground(SettingsCardRowBackground(roundsTop: true, roundsBottom: true))
            }
        }
    }
}
