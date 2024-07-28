import SwiftUI
import Charts

struct PrognosisCard: View
{
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.colorScheme) private var scheme: ColorScheme
    @EnvironmentObject private var AppSettings: Settings
    @Environment(HealthInterface.self) private var DataViewModel

    private var goalReached: Bool
    {
        // loose weight goal
        if AppSettings.weightGoal == .lose
        {
            return DataViewModel.sample.balanceMidnight >= Int(AppSettings.balanceGoal)
        }
        // gain weight goal
        else
        {
            return DataViewModel.sample.balanceMidnight <= -Int(AppSettings.balanceGoal)
        }
    }
    
    func getActiveBurnedCalories() -> Int
    {
        if AppSettings.dataSource == .custom
        {
            return DataViewModel.sample.burnedActive7
        }
        else
        {
            return DataViewModel.sample.burnedActive
        }
    }
    
    let sizeMapping: [DynamicTypeSize: CGFloat] =
    [
        .xSmall: 44,
        .small: 44,
        .medium: 44,
        .large: 44,
        .xLarge: 46,
        .xxLarge: 48,
        .xxxLarge: 50,
        .accessibility1: 52,
        .accessibility2: 54,
        .accessibility3: 56,
        .accessibility4: 58,
        .accessibility5: 60,
    ]
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            TopRowRight.padding(.top, 2)
            
            BarBalanceGraphMidnight(
                burnedActive: AppSettings.dataSource == .apple ? DataViewModel.sample.burnedActive : DataViewModel.sample.burnedActive7,
                burnedPassive: DataViewModel.sample.burnedPassive,
                burnedPassive7: DataViewModel.sample.burnedPassive7,
                consumed: DataViewModel.sample.consumed,
                consumedColor: AppSettings.consumedColor,
                burnedColor: AppSettings.burnedColor
            )
            .frame(height: sizeMapping[dynamicType, default: 44])
            .padding(.top, 6)
            .padding(.bottom, 2)
            .padding(.horizontal, 13)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
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
                                        .fill(DataViewModel.sample.balanceMidnight > 0 ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1) : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02))
                                        .stroke(DataViewModel.sample.balanceMidnight > 0 ? AppSettings.burnedColor.brighten(scheme == .light ? -0.15 : 0) : Color("TextColor").opacity(0.2), style: StrokeStyle(lineWidth: scheme == .light && DataViewModel.sample.balanceMidnight > 0 ? 1.5 : 1))
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
                            Text("\(getActiveBurnedCalories() + DataViewModel.sample.burnedPassive + DataViewModel.sample.burnedPassiveRemaining)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextColor"))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.system(size: 13))
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
                                        .fill(DataViewModel.sample.balanceMidnight < 0 ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1) : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02))
                                        .stroke(DataViewModel.sample.balanceMidnight < 0 ? AppSettings.consumedColor.brighten(scheme == .light ? -0.15 : 0) : Color("TextColor").opacity(0.2), style: StrokeStyle(lineWidth: scheme == .light && DataViewModel.sample.balanceMidnight < 0 ? 1.5 : 1))
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
                                .font(.system(size: 13))
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
            
            topGraphMiddleColumn
                .padding(.trailing, 19)
        }
    }
    
    var topGraphMiddleColumn: some View
    {
        ZStack
        {
            CircleBalanceGraph(mode: .midnight)
                .frame(width: 130, height: 130)
            
            VStack(spacing: 0)
            {
                Text("\(abs(DataViewModel.sample.balanceMidnight))")
                    .font(.system(size: 26))
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextColor"))
                    .contentTransition(.numericText(value: Double(abs(DataViewModel.sample.balanceMidnight))))
                
                Text(DataViewModel.sample.balanceMidnight > 0 ? String(localized: "Deficit") : DataViewModel.sample.balanceMidnight == 0 ? String("") : String(localized: "Surplus"))
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .offset(y: -2)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
            }
            .fontDesign(.rounded)
            
            Image(systemName: goalReached ? "checkmark" : "xmark")
                .font(.system(size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color("SecondaryTextColor"))
                .offset(y: 40) // 48
                .transaction { $0.animation = .none }
        }
    }
}

extension View
{
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View
    {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape
{
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path
    {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        
        return Path(path.cgPath)
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
        }
    }
}
