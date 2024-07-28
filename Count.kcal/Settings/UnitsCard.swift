import SwiftUI

struct UnitsCard: View
{
    @EnvironmentObject private var AppSettings: Settings

    //@State private var selectedFlavor: BalanceLayout

    var body: some View
    {
        Card("Units", titlePadding: false)
        {
            VStack(spacing: 8)
            {
                HStack
                {
                    Text("Energy")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Picker(String(""), selection: $AppSettings.energyUnit)
                    {
                        ForEach(Settings.EnergyUnit.allCases)
                        {
                            Text(verbatim: "\($0.rawValue)")
                        }
                    }
                    .pickerStyle(.palette)
                    .frame(width: 180)
                    .onChange(of: AppSettings.energyUnit)
                    { o, n in
                        if o == .kcal
                        {
                            AppSettings.balanceGoal = Int((Double(AppSettings.balanceGoal) * 4.184).rounded())
                            AppSettings.customCalPassive = Int((Double(AppSettings.customCalPassive) * 4.184).rounded())
                            AppSettings.customCalActive = Int((Double(AppSettings.customCalActive) * 4.184).rounded())
                        }
                        else
                        {
                            AppSettings.balanceGoal = Int((Double(AppSettings.balanceGoal) / 4.184).rounded())
                            AppSettings.customCalPassive = Int((Double(AppSettings.customCalPassive) / 4.184).rounded())
                            AppSettings.customCalActive = Int((Double(AppSettings.customCalActive) / 4.184).rounded())
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                HStack
                {
                    Text("Body weight")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Picker(String(""), selection: $AppSettings.weightUnit)
                    {
                        ForEach(Settings.WeightUnit.allCases)
                        {
                            Text(verbatim: "\($0.rawValue)")
                        }
                    }
                    .pickerStyle(.palette)
                    .frame(width: 180)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

#Preview
{
    NavigationView
    {
        SettingsPage()
            .environmentObject(Settings.shared)
    }
}


/*
 

 */
