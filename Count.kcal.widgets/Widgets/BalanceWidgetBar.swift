import WidgetKit
import SwiftUI

/// Calorie balance bar for small and medium widgets.
struct BalanceWidgetBar: Widget {

    @StateObject private var AppSettings = Settings.shared

    /// Selects now or midnight balance for each timeline entry.
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "BarBalanceGraphWidget",
            provider: HealthDataTimelineProvider()
        ) { entry in
            BalanceWidgetBarContent(
                entry: entry,
                mode: ModeToggleManager.buttonMode() ? .now : .midnight
            )
            .sampleHealthDataIndicator(entry)
            .containerBackground(Color("BackGroundColorBlack"), for: .widget)
            .environmentObject(AppSettings)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Calorie Dashboard")
        .description("Shows a bar graph of your calorie balance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }

}

/// Calorie balance bar with a button for now and midnight modes.
private struct BalanceWidgetBarContent: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetFamily) var family: WidgetFamily
    
    @EnvironmentObject private var AppSettings: Settings

    let entry: HealthDataTimelineProvider.Entry
    let mode: GraphMode

    var body: some View {
        switch family {
            case .systemSmall:
                ZStack(alignment: .top) {
                    HStack(alignment: .top, spacing: 0) {
                        Spacer()
                    
                        modeButton
                    }
                
                    VStack(spacing: 20) {
                        topGraph
                            .offset(y: 7.0)
                            .padding(.horizontal, -2)

                        barGraph(for: .systemSmall)
                    }
                    .padding(10)
                    .padding(.top, 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
            case .systemMedium:
                ZStack(alignment: mode == .now ? .topLeading : .top) {
                    HStack(alignment: .top, spacing: 0) {
                        Spacer()
                    
                        modeButton
                    }
                
                    VStack(spacing: 20) {
                        topGraph
                            .offset(y: 5.0)

                        barGraph(for: .systemMedium)
                    }
                    .padding(10)
                
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            
            default:
                Text(verbatim: "Widget size not supported")
        }
    }

}

extension BalanceWidgetBarContent {

    var modeButton: some View {
        Button(
            intent: ToggleViewModeIntent(),
            label: {
                ZStack(alignment: .topTrailing) {
                    // button hit-box
                    Color.clear
                        .frame(width: 50, height: 35)
                
                    HStack {
                        // button label
                        Image(systemName: mode == .now ? "sun.min.fill" : "moon.fill")
                            .foregroundColor(Color("SecondaryTextColor"))
                            .font(.caption)
                            .fontWeight(.thin)
                            .padding(.trailing, 12)
                            .padding(.leading, 10)
                            .padding(.top, 3)
                            .opacity(0.8)
                    }
                }
                .contentShape(Rectangle())
            }
        )
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    var topGraph: some View {
        if family == .systemMedium {
            HStack(alignment: .lastTextBaseline) {
                Spacer()

                BalanceDataLabelExtra(
                    icon: "bolt.fill",
                    color: AppSettings.burnedColor,
                    label: String(localized: "Burned"),
                    dataMain: burnedTotal,
                    dataTop: entry.data.burnedActive,
                    dataBottom: burnedPassiveTotal)
                .frame(minWidth: 70)

                Spacer()
                Divider().frame(height: 60)
                Spacer()
                
                BalanceDataLabelSimple(
                    icon: "fork.knife",
                    color: AppSettings.consumedColor,
                    label: String(localized: "Eaten"),
                    data: entry.data.consumed)
                .frame(minWidth: 70)

                Spacer()
                Divider().frame(height: 60)
                Spacer()
                
                topGraphBalanceColumn
                    .frame(minWidth: 70)
                
                Spacer()
            }
            .padding(.horizontal, 10)
        } else {
            HStack(alignment: .lastTextBaseline) {
                VStack {
                    Image(systemName: "bolt.fill")
                        .font(.subheadline)
                        .foregroundColor(AppSettings.burnedColor)
                        .brightness(scheme == .dark ? 0.15 : 0)
                    
                    Text("\(burnedTotal)")
                        .contentTransition(.numericText(value: Double(burnedTotal)))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("TextColor"))
                    
                    Text(String(localized: "Burned"))
                        .foregroundColor(Color("SecondaryTextColor"))
                        .font(.caption)
                        .fontWeight(.light)
                        .transaction { $0.animation = .none }
                }
                
                Spacer()
                
                VStack {
                    Image(systemName: "fork.knife")
                        .font(.subheadline)
                        .foregroundColor(AppSettings.consumedColor)
                        .brightness(scheme == .dark ? 0.15 : 0)

                    Text("\(entry.data.consumed)")
                        .contentTransition(.numericText(value: Double(entry.data.consumed)))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("TextColor"))
                    
                    Text(String(localized: "Eaten"))
                        .foregroundColor(Color("SecondaryTextColor"))
                        .font(.caption)
                        .fontWeight(.light)
                        .transaction { $0.animation = .none }
                }
            }
            .padding(.horizontal, 10)
            .fontDesign(.rounded)
        }
    }
    
    var topGraphBalanceColumn: some View {
        VStack(spacing: 0) {
            if !AppSettings.hideCalorieStatusIcons {
                Image(systemName: goalReached ? "checkmark" : "xmark")
                    .font(.system(size: 14))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("SecondaryTextColor"))
                    .padding(.bottom, 4)
                    .transaction { $0.animation = .none }
            }
            
            Text("\(abs(balance))")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color("TextColor"))
                .contentTransition(.numericText(value: Double(abs(balance))))
            
            Text(String(localized: balance > 0 ? "Deficit" : "Surplus"))
                .font(.caption)
                .fontWeight(.light)
                .foregroundColor(Color("TextColor"))
                .transaction { $0.animation = .none }
        }
        .fontDesign(.rounded)
    }

}

extension BalanceWidgetBarContent {

    private func barGraph(for family: WidgetFamily) -> some View {
        BarBalanceGraph(mode: mode, animateNumericValues: true)
            .environment(HealthInterface(entry.data))
            .frame(height: 44)
            .padding(.bottom, 4)
            .padding(.horizontal, family == .systemSmall ? 3 : 20)
            .fontDesign(.rounded)
    }
        
    private var energy: EnergyBalance { mode == .now ? entry.data.now : entry.data.midnight }

    private var balance: Int { energy.balance }

    private var burnedTotal: Int { energy.burned }

    private var burnedPassiveTotal: Int { energy.resting + energy.restingRemaining }
    
    private var goalReached: Bool {
        energy.meetsGoal(AppSettings.balanceGoal, isLoss: AppSettings.weightGoal == .lose)
    }
    
}

#Preview(as: .systemMedium) {
    BalanceWidgetBar()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}
