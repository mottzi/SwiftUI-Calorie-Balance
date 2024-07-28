import SwiftUI

struct CaloriesCardTopRow: View 
{
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.colorScheme) private var scheme: ColorScheme
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel
        
    var body: some View
    {
        TopRowRight
    }
    
    var TopRowRight: some View
    {
        HStack(spacing: 0)
        {
            VStack(alignment: .leading, spacing: dynamicType <= .xxLarge ? 16 : 4)
            {
                HStack(spacing: dynamicType <= .xxLarge ? 14 : 10)
                {
                    if dynamicType <= .accessibility3
                    {
                        Image(systemName: "bolt.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 23, height: 23)
                            .foregroundStyle(AppSettings.burnedColor.gradient)
                            .brightness(scheme == .dark ? 0.15 : 0)
                            .background
                            {
                                if dynamicType <= .xxLarge
                                {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(DataViewModel.sample.balanceNow > 0 ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1) : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02))
                                        .stroke(DataViewModel.sample.balanceNow > 0 ? AppSettings.burnedColor.brighten(scheme == .light ? -0.15 : 0) : Color("TextColor").opacity(0.2), style: StrokeStyle(lineWidth: scheme == .light && DataViewModel.sample.balanceNow > 0 ? 1.5 : 1))
                                        .padding(-8)
                                        .brightness(level: .secondary)
                                }
                            }
                            .padding(dynamicType <= .xxLarge ? 8 : 0)
                    }
                    
                    VStack(alignment: .leading, spacing: 0)
                    {
                        HStack(alignment: .lastTextBaseline, spacing: 2)
                        {
                            Text("\(DataViewModel.sample.burnedActive + DataViewModel.sample.burnedPassive)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextColor"))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            
                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.caption)
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .fontWeight(.medium)
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        }
                        
                        Text("Burned")
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }
                    .transaction { $0.animation = .none }
                }
                             
                HStack(spacing: dynamicType <= .xxLarge ? 14 : 10)
                {
                    if dynamicType <= .accessibility3
                    {
                        Image(systemName: "fork.knife")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 23, height: 23)
                            .foregroundStyle(AppSettings.consumedColor.gradient)
                            .brightness(scheme == .dark ? 0.15 : 0)
                            .background
                            {
                                if dynamicType <= .xxLarge
                                {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(DataViewModel.sample.balanceNow < 0 ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1) : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02))
                                        .stroke(DataViewModel.sample.balanceNow < 0 ? AppSettings.consumedColor.brighten(scheme == .light ? -0.15 : 0) : Color("TextColor").opacity(0.2), style: StrokeStyle(lineWidth: scheme == .light && DataViewModel.sample.balanceNow < 0 ? 1.5 : 1))
                                        .brightness(level: .secondary)
                                        .padding(-8)
                                }
                            }
                            .padding(dynamicType <= .xxLarge ? 8 : 0)
                    }

                    VStack(alignment: .leading, spacing: 0)
                    {
                        HStack(alignment: .lastTextBaseline, spacing: 2)
                        {
                            Text("\(DataViewModel.sample.consumed)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextColor"))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.caption)
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .fontWeight(.medium)
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        }

                        Text("Eaten")
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }
                    .transaction { $0.animation = .none }
                }
            }
            .fontDesign(.rounded)
            .padding(.leading, 13)
            .offset(y: -4)
            .fixedSize()
                
            Spacer()
            
            CaloriesCardTopRowCenter()
                .padding(.trailing, 19)
        }
    }
}

#Preview
{
    NavigationView
    {
        ZStack
        {
            Settings.shared.AppBackground.ignoresSafeArea(.all)
            
            Pager(lb: 6, tb: 1)
                .environmentObject(Settings.shared)
                .environment(WeightDataViewModel())
                .environment(Streak())
        }
    }
}
