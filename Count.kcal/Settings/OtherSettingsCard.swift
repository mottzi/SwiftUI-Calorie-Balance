import SwiftUI
import WidgetKit

struct OtherSettingsCard: View {

    @EnvironmentObject private var AppSettings: Settings

    var body: some View {
        Card("Other", innerPadding: 0) {
            VStack(spacing: 0) {
                DashboardCustomizationRow()

                Divider()
                    .padding(.horizontal, 24)

                Toggle(isOn: $AppSettings.hideCalorieStatusIcons) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hide goal status icons")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("TextColor"))

                        Text("Checkmark or cross on calorie cards")
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryTextColor"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .onChange(of: AppSettings.hideCalorieStatusIcons) {
                    WidgetCenter.shared.reloadAllTimelines()
                }

                Divider()
                    .padding(.horizontal, 24)

                Toggle(isOn: $AppSettings.showCalorieLabelBackgrounds) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calorie label backgrounds")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("TextColor"))

                        Text("Add contrast behind bar values in the app and widgets")
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryTextColor"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .onChange(of: AppSettings.showCalorieLabelBackgrounds) {
                    WidgetCenter.shared.reloadAllTimelines()
                }

                if AppSettings.showCalorieLabelBackgrounds {
                    VStack(spacing: 0) {
                        BackgroundColorSection(
                            selection: $AppSettings.calorieLabelBackground,
                            showsDivider: false,
                            showsTitle: false,
                            color: \.labelBackgroundColor
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .onChange(of: AppSettings.calorieLabelBackground) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

}
