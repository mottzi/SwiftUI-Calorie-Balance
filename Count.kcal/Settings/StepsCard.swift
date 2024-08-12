import SwiftUI

struct StepsCard: View
{
    @EnvironmentObject private var AppSettings: Settings
    @FocusState var focusedField: Field?
    
    var body: some View
    {
        Card("Steps")
        {
            HStack
            {
                Text("Daily Goal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                TextField(String(""), value: $AppSettings.stepsGoal, format: .number)
                    .focused($focusedField, equals: .steps)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("TextColor"))
                    .underline()
            }
            .padding(.horizontal, 8)
            .padding(.trailing, 8)
        }
    }
}

#Preview
{
    NavigationView
    {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
