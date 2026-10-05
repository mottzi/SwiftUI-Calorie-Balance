import SwiftUI
import WidgetKit

struct OtherSettingsCard: View {

    @EnvironmentObject private var AppSettings: Settings

    var body: some View {
        Card("Other") {
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
            .padding(.horizontal, 8)
            .onChange(of: AppSettings.hideCalorieStatusIcons) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

}
