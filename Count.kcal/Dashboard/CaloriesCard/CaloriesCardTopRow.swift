import SwiftUI

/// Burned and eaten totals beside the selected balance circle.
struct CaloriesCardTopRow: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.colorScheme) private var scheme: ColorScheme

    @EnvironmentObject private var AppSettings: Settings

    @Environment(HealthInterface.self) private var DataViewModel

    let mode: GraphMode

    var body: some View {
        (dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .center, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 0))) {
            VStack(alignment: .leading, spacing: dynamicType <= .xxLarge ? 16 : 4) {
                HStack(spacing: dynamicType <= .xxLarge ? 14 : 10) {
                    if dynamicType <= .accessibility3 {
                        Image(systemName: "bolt.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 23, height: 23)
                            .foregroundStyle((energy.isEmpty ? Color("SecondaryTextColor") : AppSettings.burnedColor).gradient)
                            .brightness(!energy.isEmpty && scheme == .dark ? 0.15 : 0)
                            .background {
                                if dynamicType <= .xxLarge {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(balance > 0
                                            ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1)
                                            : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02))
                                        .stroke(
                                            balance > 0
                                                ? AppSettings.burnedColor.brighten(scheme == .light ? -0.15 : 0)
                                                : Color("TextColor").opacity(0.2),
                                            style: StrokeStyle(
                                                lineWidth: scheme == .light && balance > 0 ? 1.5 : 1
                                            )
                                        )
                                        .padding(-8)
                                        .brightness(level: .secondary)
                                }
                            }
                            .padding(dynamicType <= .xxLarge ? 8 : 0)
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(energy.burned)")
                                .contentTransition(.numericText(value: Double(energy.burned)))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(energy.isEmpty ? "SecondaryTextColor" : "TextColor"))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            
                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(mode == .now ? .caption : .system(size: 13))
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .fontWeight(.medium)
                                .transaction { $0.animation = .none }
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        }
                        
                        Text("Burned")
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .transaction { $0.animation = .none }
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }
                }
                             
                HStack(spacing: dynamicType <= .xxLarge ? 14 : 10) {
                    if dynamicType <= .accessibility3 {
                        Image(systemName: "fork.knife")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 23, height: 23)
                            .foregroundStyle((energy.isEmpty ? Color("SecondaryTextColor") : AppSettings.consumedColor).gradient)
                            .brightness(!energy.isEmpty && scheme == .dark ? 0.15 : 0)
                            .background {
                                if dynamicType <= .xxLarge {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(balance < 0
                                            ? Color("TextColor").opacity(scheme == .dark ? 0.1 : 0.1)
                                            : Color("TextColor").opacity(scheme == .dark ? 0 : 0.02))
                                        .stroke(
                                            balance < 0
                                                ? AppSettings.consumedColor.brighten(scheme == .light ? -0.15 : 0)
                                                : Color("TextColor").opacity(0.2),
                                            style: StrokeStyle(
                                                lineWidth: scheme == .light && balance < 0 ? 1.5 : 1
                                            )
                                        )
                                        .brightness(level: .secondary)
                                        .padding(-8)
                                }
                            }
                            .padding(dynamicType <= .xxLarge ? 8 : 0)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(DataViewModel.sample.consumed)")
                                .contentTransition(.numericText(value: Double(DataViewModel.sample.consumed)))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(energy.isEmpty ? "SecondaryTextColor" : "TextColor"))
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

                            Text(verbatim: AppSettings.energyUnit == .kJ ? "kJ" : "kcal")
                                .font(mode == .now ? .caption : .system(size: 13))
                                .foregroundStyle(Color("SecondaryTextColor"))
                                .fontWeight(.medium)
                                .transaction { $0.animation = .none }
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        }

                        Text("Eaten")
                            .font(.caption)
                            .fontWeight(.light)
                            .foregroundColor(Color("SecondaryTextColor"))
                            .transaction { $0.animation = .none }
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }
                }
            }
            .fontDesign(.rounded)
            .padding(.leading, 13)
            .offset(y: dynamicType.isAccessibilitySize ? 0 : -4)
            .fixedSize(horizontal: !dynamicType.isAccessibilitySize, vertical: !dynamicType.isAccessibilitySize)
            .frame(maxWidth: dynamicType.isAccessibilitySize ? .infinity : nil, alignment: .leading)
                
            if !dynamicType.isAccessibilitySize {
                Spacer()
            }
            
            CaloriesCardTopRowCenter(mode: mode)
                .padding(.trailing, dynamicType.isAccessibilitySize ? 0 : 19)
        }
    }

}

extension CaloriesCardTopRow {

    private var energy: EnergyBalance {
        mode == .now ? DataViewModel.sample.now : DataViewModel.sample.midnight
    }

    private var balance: Int { energy.balance }

}

#Preview { PreviewPager }
