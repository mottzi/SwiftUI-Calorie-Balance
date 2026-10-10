import WidgetKit
import SwiftUI

/// Calorie balance circle with nutrition progress in the large widget.
struct BalanceWidgetCircle: Widget {

    @StateObject private var AppSettings = Settings.shared

    /// Selects now or midnight balance for each timeline entry.
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "CircleBalanceGraphWidget",
            provider: HealthDataTimelineProvider()
        ) { entry in
            BalanceWidgetCircleContent(
                entry: entry,
                mode: ModeToggleManager.buttonMode() ? .now : .midnight
            )
            .environmentObject(AppSettings)
            .sampleHealthDataIndicator(entry)
            .containerBackground(Color("BackGroundColorBlack"), for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Calorie Dashboard")
        .description("Shows a circular graph of your calorie balance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }

}

/// Calorie balance circle with a button for now and midnight modes.
private struct BalanceWidgetCircleContent: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetFamily) var family: WidgetFamily
    @Environment(\.widgetRenderingMode) private var renderingMode
    
    @EnvironmentObject private var AppSettings: Settings

    var entry: HealthDataTimelineProvider.Entry
    let mode: GraphMode

    var body: some View {
        switch family {
            case .systemSmall:
                ZStack(alignment: .center) {
                    HStack(spacing: 0) {
                        Spacer()
                    
                        modeLabel
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                    topGraphBalanceColumn
                        .padding(.top, 5)
                
                    GeometryReader { geo in
                        HStack(spacing: 20) {
                            HStack(spacing: 2) {
                                Text("\(burnedCalories)")
                                    .contentTransition(.numericText(value: Double(burnedCalories)))
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
                        
                            HStack(spacing: 2) {
                                Image(systemName: "fork.knife")
                                    .resizable()
                                    .scaledToFit()
                                    .bold()
                                    .frame(width: 10, height: 10)
                                    .foregroundStyle(AppSettings.consumedColor)
                                    .brightness(level: .secondary)

                                Text("\(entry.data.consumed)")
                                    .contentTransition(.numericText(value: Double(entry.data.consumed)))
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
                ZStack(alignment: .top) {
                    HStack(alignment: .top, spacing: 0) {
                        Spacer()
                    
                        modeLabel
                    }
                
                    topGraph
                }

            case .systemLarge:
                largeDashboard

            default:
                if mode == .now {
                    Text("Widget size not supported")
                } else {
                    Text(verbatim: "Widget size not supported")
                }
        }
    }
        
}

extension BalanceWidgetCircleContent {

    private var summaryTopInset: CGFloat { 24 }
    private var summaryHeight: CGFloat { 130 }

    private var largeDashboard: some View {
        ViewThatFits(in: .vertical) {
            largeDashboardContent(sectionSpacing: 24)
                .padding(.bottom, 20)

            largeDashboardContent(sectionSpacing: 12)
                .padding(.bottom, 12)
        }
        .padding(.top, summaryTopInset)
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .topTrailing) {
            modeLabel
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private func largeDashboardContent(sectionSpacing: CGFloat) -> some View {
        VStack(spacing: sectionSpacing) {
            // Match the app's calorie card before separating the nutrient section.
            VStack(spacing: 6) {
                topGraphContent
                    .frame(height: summaryHeight)
                    .accessibilityElement(children: .combine)

                BarBalanceGraph(mode: mode, animateNumericValues: true)
                    .environment(HealthInterface(entry.data))
                    .frame(height: 44)
                    .accessibilityHidden(true)
            }

            NutritionWidgetNow(entry: entry)
        }
        .fontDesign(.rounded)
    }

    var modeLabel: some View {
        Button(
            intent: ToggleViewModeIntent(),
            label: {
                ZStack(alignment: .topTrailing) {
                    // button hit-box
                    Color.clear
                        .frame(width: 50, height: 35)
                
                    if mode == .midnight {
                        HStack {
                            modeIcon
                        }
                    } else {
                        modeIcon
                    }
                }
                .contentShape(Rectangle())
            }
        )
        .buttonStyle(.plain)
    }

    var modeIcon: some View {
        Image(systemName: mode == .now ? "sun.min.fill" : "moon.fill")
            .foregroundColor(Color("SecondaryTextColor"))
            .font(.caption)
            .fontWeight(.thin)
            .padding(.trailing, 12)
            .padding(.leading, 10)
            .padding(.top, 3)
            .opacity(0.8)
    }
    
    var topGraphBalanceColumn: some View {
        ZStack {
            CircleBalanceGraph(
                mode: mode,
                accentedWidget: renderingMode == .accented
            )
                .frame(width: 130, height: 130)
                .environment(HealthInterface(entry.data))
            
            VStack(spacing: 0) {
                Text("\(abs(balance))")
                    .font(.system(size: 26))
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextColor"))
                    .contentTransition(.numericText(value: Double(abs(balance))))
                
                Text(balance > 0
                    ? String(localized: "Deficit")
                    : balance == 0
                        ? (family == .systemLarge ? String(localized: "Balance") : "")
                        : String(localized: "Surplus"))
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .offset(y: -2)
            }
            .fontDesign(.rounded)

            if !AppSettings.hideCalorieStatusIcons && (family != .systemLarge || energy.graphTotal > 0) {
                Image(systemName: goalReached ? "checkmark" : "xmark")
                    .font(.system(size: 12))
                    .fontWeight(.semibold)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .offset(y: 40)
                    .transaction { $0.animation = .none }
            }
        }
    }

    var topGraph: some View {
        topGraphContent
            .frame(height: summaryHeight)
            .padding(.top, summaryTopInset)
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    var topGraphContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "bolt.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .foregroundStyle(AppSettings.burnedColor.gradient)
                        .brightness(scheme == .dark ? 0.15 : 0)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    balance > 0
                                        ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1)
                                        : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02)
                                )
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

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(burnedCalories)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextColor"))
                                .contentTransition(.numericText(value: Double(burnedCalories)))
                            
                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .fontWeight(.medium)
                                .transaction { $0.animation = .none }
                        }
                        
                        Text(String(localized: "Burned"))
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .transaction { $0.animation = .none }
                    }
                }
                             
                HStack(spacing: 14) {
                    Image(systemName: "fork.knife")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .foregroundStyle(AppSettings.consumedColor.gradient)
                        .brightness(scheme == .dark ? 0.15 : 0)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    balance < 0
                                        ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1)
                                        : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02)
                                )
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
                    
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(entry.data.consumed)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("TextColor"))
                                .contentTransition(.numericText(value: Double(entry.data.consumed)))

                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .fontWeight(.medium)
                                .transaction { $0.animation = .none }
                        }

                        Text(String(localized: "Eaten"))
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .transaction { $0.animation = .none }
                    }
                }
            }
            .fontDesign(.rounded)
            .offset(y: -4)
            .fixedSize()
                
            Spacer()
            
            topGraphBalanceColumn
        }
    }
    
}

extension BalanceWidgetCircleContent {

    private var energy: EnergyBalance { mode == .now ? entry.data.now : entry.data.midnight }

    private var balance: Int { energy.balance }

    private var burnedCalories: Int { energy.burned }
    
    private var goalReached: Bool {
        energy.meetsGoal(AppSettings.balanceGoal, isLoss: AppSettings.weightGoal == .lose)
    }
    
}

#Preview(as: .systemSmall) {
    BalanceWidgetCircle()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
}

#Preview(as: .systemLarge) {
    BalanceWidgetCircle()
}
timeline: {
    HealthDataEntry(date: .now, data: HealthData.example(for: .now))
    HealthDataEntry(date: .now, data: HealthData.example(for: .now, balance: .surplus))
    HealthDataEntry(date: .now, data: HealthData.empty(for: .now))
}
