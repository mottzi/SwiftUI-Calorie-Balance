import SwiftUI

struct StepsCard: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var AppSettings: Settings

    @FocusState var focusedField: Field?
    
    var body: some View {
        Card("Steps") {
            (dynamicType.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout())) {
                Text("Daily Goal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if !dynamicType.isAccessibilitySize { Spacer() }
                
                TextField(String(""), value: $AppSettings.stepsGoal, format: .number)
                    .focused($focusedField, equals: .steps)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(dynamicType.isAccessibilitySize ? .leading : .trailing)
                    .frame(maxWidth: .infinity, alignment: dynamicType.isAccessibilitySize ? .leading : .trailing)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("TextColor"))
                    .underline()
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .padding(.horizontal, 8)
            .padding(.trailing, 8)
        }
    }

}

#Preview {
    NavigationView {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
