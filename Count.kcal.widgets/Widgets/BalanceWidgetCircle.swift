import WidgetKit
import SwiftUI

struct BalanceWidgetCircle: Widget
{
    @StateObject private var AppSettings = Settings.shared

    var body: some WidgetConfiguration
    {
        StaticConfiguration(
            kind: "CircleBalanceGraphWidget",
            provider: HealthDataTimelineProvider())
            { entry in
                BalanceWidgetCircleContent(
                    entry: entry,
                    mode: ModeToggleManager.buttonMode() ? .now : .midnight)
                    .environmentObject(AppSettings)
                    .containerBackground(Color("BackGroundColor"), for: .widget)
            }
            .contentMarginsDisabled()
            .configurationDisplayName("Calorie Dashboard")
            .description("Shows a circular graph of your calorie balance.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Calorie circle widget content for the selected balance mode.
private struct BalanceWidgetCircleContent: View
{

    @Environment(\.colorScheme) private var scheme

    @EnvironmentObject private var AppSettings: Settings

    @Environment(\.widgetFamily) var family: WidgetFamily
    
    var entry: HealthDataTimelineProvider.Entry
    let mode: GraphMode

    private var balance: Int
    {
        mode == .now ? entry.data.balanceNow : entry.data.balanceMidnight
    }

    private var burnedCalories: Int
    {
        mode == .now
            ? entry.data.burnedActive + entry.data.burnedPassive
            : entry.data.burnedActiveMidnight + entry.data.burnedPassive + entry.data.burnedPassiveRemaining
    }
    
    private var goalReached: Bool
    {
        if AppSettings.weightGoal == .lose
        {
            return balance >= Int(AppSettings.balanceGoal)
        }
        else
        {
            return balance <= -Int(AppSettings.balanceGoal)
        }
    }
    
    var body: some View
    {
        switch family
        {
            case .systemSmall:
            ZStack(alignment: .center)
            {
                HStack(spacing: 0)
                {
//                    timeReloadButton
                    
                    Spacer()
                    
                    modeLabel
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                topGraphBalanceColumn
                    .padding(.top, 5)
                
                GeometryReader
                { geo in
                    HStack(spacing: 20)
                    {
                        HStack(spacing: 2)
                        {
                            Text("\(burnedCalories)")
                                .fontWeight(.medium)
                                .foregroundStyle(Color("TextColor"))

                            Image(systemName: "bolt.fill")
                                .resizable()
                                .scaledToFit()
                                .bold()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(AppSettings.burnedColor)
                                .brightness(level: .secondary)
                        }
                        .fontDesign(.rounded)
                        .font(.caption)
                        .fontWeight(.light)
                        .frame(width: geo.size.width / 2 - 10, alignment: .trailing)
                        
                        HStack(spacing: 2)
                        {
                            Image(systemName: "fork.knife")
                                .resizable()
                                .scaledToFit()
                                .bold()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(AppSettings.consumedColor)
                                .brightness(level: .secondary)

                            Text("\(entry.data.consumed)")
                                .fontWeight(.medium)
                                .foregroundStyle(Color("TextColor"))
                        }
                        .fontDesign(.rounded)
                        .font(.caption)
                        .fontWeight(.light)
                        .frame(width: geo.size.width / 2 - 10, alignment: .leading)
                    }
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
                
            case .systemMedium:
            ZStack(alignment: .top)
            {
                HStack(alignment: .top, spacing: 0)
                {
//                    timeReloadButton
                    
                    Spacer()
                    
                    modeLabel
                }
                
                topGraph
            }

            default:
            if mode == .now
            {
                Text("Widget size not supported")
            }
            else
            {
                Text(verbatim: "Widget size not supported")
            }
        }
    }
        
    var modeLabel: some View
    {
        Button(intent: ToggleViewModeIntent(), label:
        {
            ZStack(alignment: .topTrailing)
            {
                // button hit-box
                Color.clear
                    .frame(width: 50, height: 35)
                
                if mode == .midnight
                {
                    HStack
                    {
                        modeIcon
                    }
                }
                else
                {
                    modeIcon
                }
            }
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
    }

    var modeIcon: some View
    {
        Image(systemName: mode == .now ? "sun.min.fill" : "moon.fill")
            .foregroundColor(Color("SecondaryTextColor"))
            .font(.caption)
            .fontWeight(.thin)
            .padding(.trailing, 12)
            .padding(.leading, 10)
            .padding(.top, 3)
            .background
            {
                if scheme == .dark
                {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 20,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 20,
                        style: .circular
                    )
                        .fill(Color("BackGroundColor").gradient)
                }
            }
            .opacity(0.8)
    }
    
    var timeReloadButton: some View
    {
        Button(intent: TestAppIntent())
        {
            ZStack(alignment: .topLeading)
            {
                // button hit-box
                Color.clear
                    .frame(width: 50, height: 35)
                
                // button label
                Text(verbatim: "\(entry.date.shortTime)")
                    .foregroundStyle(Color("SecondaryTextColor"))
                    .font(.caption)
                    .fontWeight(.thin)
                    .padding(.leading, 12)
                    .padding(.trailing, 9)
                    .padding(.top, 2)
                    .background
                    {
                        if scheme == .dark
                        {
                            UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 20, topTrailingRadius: 0, style: .continuous)
                                .fill(Color("BackGroundColor").gradient)
                        }
                    }
                    
                    .opacity(0.8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    var topGraph: some View
    {
        if mode == .now
        {
            topGraphContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 13)
                .padding(.horizontal, 30)
        }
        else
        {
            topGraphContent
                .padding(.top, 13)
                .padding(.horizontal, 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var topGraphContent: some View
    {
        HStack(spacing: 0)
        {
            VStack(alignment: .leading, spacing: 16)
            {
                HStack(spacing: 14)
                {
                    Image(systemName: "bolt.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .foregroundStyle(AppSettings.burnedColor.gradient)
                        .brightness(scheme == .dark ? 0.15 : 0)
                        .background
                        {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(balance > 0
                                    ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1)
                                    : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02))
                                .stroke(
                                    balance > 0
                                        ? AppSettings.burnedColor.brighten(scheme == .light ? -0.15 : 0)
                                        : Color("TextColor").opacity(0.2),
                                    style: StrokeStyle(lineWidth: scheme == .light && balance > 0 ? 1.5 : 1)
                                )
                                .padding(-8)
                                .brightness(level: .secondary)
                        }
                        .padding(8)

                    VStack(alignment: .leading, spacing: 0)
                    {
                        HStack(alignment: .lastTextBaseline, spacing: 2)
                        {
                            Text("\(burnedCalories)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextColor"))
                            
                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .fontWeight(.medium)
                        }
                        
                        Text(String(localized: "Burned"))
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                    }
                    .transaction { $0.animation = .none }
                }
                             
                HStack(spacing: 14)
                {
                    Image(systemName: "fork.knife")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .foregroundStyle(AppSettings.consumedColor.gradient)
                        .brightness(scheme == .dark ? 0.15 : 0)
                        .background
                        {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(balance < 0
                                    ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1)
                                    : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02))
                                .stroke(
                                    balance < 0
                                        ? AppSettings.consumedColor.brighten(scheme == .light ? -0.15 : 0)
                                        : Color("TextColor").opacity(0.2),
                                    style: StrokeStyle(lineWidth: scheme == .light && balance < 0 ? 1.5 : 1)
                                )
                                .brightness(level: .secondary)
                                .padding(-8)

                        }
                        .padding(8)
                    
                    VStack(alignment: .leading, spacing: 0)
                    {
                        HStack(alignment: .lastTextBaseline, spacing: 2)
                        {
                            Text("\(entry.data.consumed)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextColor"))

                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .fontWeight(.medium)
                        }

                        Text(String(localized: "Eaten"))
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                    }
                    .transaction { $0.animation = .none }
                }
            }
            .fontDesign(.rounded)
            .offset(y: -4)
            .fixedSize()
                
            Spacer()
            
            topGraphBalanceColumn
        }
    }
    
    var topGraphBalanceColumn: some View
    {
        ZStack
        {
            CircleBalanceGraph(mode: mode, groupNowGeometry: mode == .midnight)
                .frame(width: 130, height: 130)
                .environment(HealthInterface(entry.data))
                .brightness(-0.05)
            
            VStack(spacing: 0)
            {
                Text("\(abs(balance))")
                    .font(.system(size: 26))
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextColor"))
                    .contentTransition(.numericText(value: Double(abs(balance))))
                
                Text(balance > 0 ? String(localized: "Deficit") : balance == 0 ? String("") : String(localized: "Surplus"))
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .offset(y: -2)
            }
            .fontDesign(.rounded)

            Image(systemName: goalReached ? "checkmark" : "xmark")
                .font(.system(size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color("SecondaryTextColor"))
                .offset(y: 40)
                .transaction { $0.animation = .none }
        }
    }

}

#Preview(as: .systemSmall)
{
    BalanceWidgetCircle()
}
timeline:
{
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
