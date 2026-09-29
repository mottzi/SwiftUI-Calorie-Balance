import SwiftUI

struct CalorieColorSection: View {

    @EnvironmentObject private var AppSettings: Settings

    var body: some View {
        HStack {
            Text("Burned Calories")
                .font(.subheadline)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            ColorPicker(String(""), selection: $AppSettings.burnedColor, supportsOpacity: false)
                .brightness(level: .primary)
                .saturation(Settings.baseSaturation)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)

        Divider()

        HStack {
            Text("Consumed Calories")
                .font(.subheadline)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            ColorPicker(String(""), selection: $AppSettings.consumedColor, supportsOpacity: false)
                .brightness(level: .primary)
                .saturation(Settings.baseSaturation)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)

        Divider()
    }

}
