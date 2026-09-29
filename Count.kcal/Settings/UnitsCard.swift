import SwiftUI

struct UnitsCard: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var AppSettings: Settings

    var body: some View {
        Card("Units", titlePadding: false) {
            VStack(spacing: 8) {
                (dynamicType.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                    : AnyLayout(HStackLayout())) {
                    Text("Energy")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if !dynamicType.isAccessibilitySize { Spacer() }
                    
                    Picker(String(""), selection: $AppSettings.energyUnit) {
                        ForEach(Settings.EnergyUnit.allCases) {
                            Text(verbatim: "\($0.rawValue)")
                        }
                    }
                    .pickerStyle(.palette)
                    .frame(width: 180)
                    .onChange(of: AppSettings.energyUnit) { o, n in
                        if o == .kcal {
                            AppSettings.balanceGoal = Int((Double(AppSettings.balanceGoal) * 4.184).rounded())
                            AppSettings.customCalPassive = Int((Double(AppSettings.customCalPassive) * 4.184).rounded())
                            AppSettings.customCalActive = Int((Double(AppSettings.customCalActive) * 4.184).rounded())
                        } else {
                            AppSettings.balanceGoal = Int((Double(AppSettings.balanceGoal) / 4.184).rounded())
                            AppSettings.customCalPassive = Int((Double(AppSettings.customCalPassive) / 4.184).rounded())
                            AppSettings.customCalActive = Int((Double(AppSettings.customCalActive) / 4.184).rounded())
                        }
                    }
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                
                Divider()
                    .padding(.vertical, 4)
                
                (dynamicType.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                    : AnyLayout(HStackLayout())) {
                    Text("Body weight")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if !dynamicType.isAccessibilitySize { Spacer() }
                    
                    Picker(String(""), selection: $AppSettings.weightUnit) {
                        ForEach(Settings.WeightUnit.allCases) {
                            Text(verbatim: "\($0.rawValue)")
                        }
                    }
                    .pickerStyle(.palette)
                    .frame(width: 180)
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            }
            .padding(.horizontal, 8)
        }
    }

}

#Preview {
    NavigationView {
        SettingsPage()
            .environmentObject(Settings.shared)
    }
}
