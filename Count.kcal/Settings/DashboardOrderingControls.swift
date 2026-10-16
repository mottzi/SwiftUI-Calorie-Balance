import SwiftUI

struct DashboardOrderingControls: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        Group {
            SettingsSection("Daily cards") {
                SettingsReorderRows(order: \.dailyCards, move: settings.moveDailyCards) { card in
                    Text(card.title)
                        .foregroundStyle(Color(card == .steps && !settings.showDashboardSteps
                            ? "SecondaryTextColor" : "TextColor"))
                        .opacity(card == .steps && !settings.showDashboardSteps ? 0.5 : 1)
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

            Section {
                Toggle("Disable steps", isOn: $settings.disableDashboardSteps)
                    .font(.subheadline.weight(.semibold))
                    .environment(\.editMode, .constant(.inactive))
                    .moveDisabled(true)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                    .listRowBackground(SettingsCardRowBackground(roundsTop: true, roundsBottom: true))
            }
            .listSectionSeparator(.hidden)
        }
    }
}
