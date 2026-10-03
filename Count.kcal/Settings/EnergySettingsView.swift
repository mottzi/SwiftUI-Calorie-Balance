import SwiftUI

/// Controls for the weight goal, energy source, and daily balance target.
struct EnergySettingsView: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.colorScheme) private var scheme: ColorScheme

    @EnvironmentObject private var AppSettings: Settings
    
    @FocusState var focusedField: Field?
    
    @State private var healthDataMode = HealthDataMode.shared
        
    var body: some View {
        VStack(spacing: 22) {
            (dynamicType.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .center, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .bottom))) {
                if !dynamicType.isAccessibilitySize { Spacer() }
                
                VStack(spacing: 12) {
                    Text("I want to...")
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .foregroundStyle(Color("TextColor"))
                    
                    IconPicker(
                        firstIcon: "arrowshape.down.fill",
                        secondIcon: "arrowshape.up.fill",
                        selection: $AppSettings.weightGoal
                    )
                        .frame(width: 100, height: 35)
                        .sensoryFeedback(.selection, trigger: AppSettings.weightGoal)

                    
                    Text(AppSettings.weightGoal == .lose ? "Lose Weight" : "Gain Weight")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .animation(.linear, value: AppSettings.weightGoal)
                        .fontDesign(.rounded)
                        .foregroundStyle(Color("TextColor"))
                        
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(.horizontal, dynamicType.isAccessibilitySize ? 20 : 30)
                .padding(.vertical, 20)
                .frame(maxWidth: dynamicType.isAccessibilitySize ? .infinity : nil)
                .modifier(EnergySettingsCardStyle())

                if !dynamicType.isAccessibilitySize { Spacer() }
                
                VStack(spacing: 12) {
                    Text("For burned calories, use...")
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .foregroundStyle(Color("TextColor"))
                        .frame(width: dynamicType.isAccessibilitySize ? nil : 100)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if healthDataMode.usesSampleData {
                        Image(systemName: "testtube.2")
                            .font(.title3)
                            .foregroundStyle(Color("SecondaryTextColor"))
                            .frame(width: 100, height: 35)
                            .accessibilityHidden(true)
                    } else {
                        IconPicker(
                            firstIcon: "heart.fill",
                            secondIcon: "pencil.and.list.clipboard",
                            selection: $AppSettings.dataSource
                        )
                        .frame(width: 100, height: 35)
                        .sensoryFeedback(.selection, trigger: AppSettings.dataSource)
                    }

                    Text(
                        healthDataMode.usesSampleData
                            ? "Sample Data"
                            : AppSettings.dataSource == .apple ? "Apple Health" : "Custom Data"
                    )
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .animation(.linear, value: AppSettings.dataSource)
                        .fontDesign(.rounded)
                        .foregroundStyle(Color("TextColor"))
                    
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(.horizontal, dynamicType.isAccessibilitySize ? 20 : 30)
                .padding(.vertical, 20)
                .frame(maxWidth: dynamicType.isAccessibilitySize ? .infinity : nil)
                .modifier(EnergySettingsCardStyle())
                .disabled(healthDataMode.usesSampleData)

                if !dynamicType.isAccessibilitySize { Spacer() }
            }
            .padding(.horizontal, dynamicType.isAccessibilitySize ? 16 : 0)
                        
            VStack(spacing: 12) {
                BurnedEnergyInputRow(.resting, focusedField: $focusedField, usesCustomEnergy: AppSettings.usesCustomEnergy)
                    .frame(height: dynamicType.isAccessibilitySize ? nil : 20)
                    .padding(.top, 6)
                    .padding(.horizontal, 15)
                    .padding(.bottom, 8)

                BurnedEnergyInputRow(.active, focusedField: $focusedField, usesCustomEnergy: AppSettings.usesCustomEnergy)
                    .frame(height: dynamicType.isAccessibilitySize ? nil : 20)
                    .padding(.horizontal, 15)
                
                (dynamicType.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .lastTextBaseline))) {
                    HStack(spacing: 8) {
                        Text("Total Burned")
                            .foregroundStyle(Color("TextColor"))
                        
                        if !AppSettings.isBurnedValid {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.red.gradient)
                                .offset(y: -1)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: !dynamicType.isAccessibilitySize, vertical: true)
                    
                    if !dynamicType.isAccessibilitySize { Spacer() }
                    
                    HStack(alignment: .lastTextBaseline) {
                        Text(
                            """
                            \(AppSettings.usesCustomEnergy
                                ? (AppSettings.customCalActive + AppSettings.customCalPassive)
                                : (AppSettings.showActive + AppSettings.showResting))
                            """
                        )
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(x: 3)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                        
                        EnergyUnitLabel()
                    }
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .frame(height: dynamicType.isAccessibilitySize ? nil : 20)
                .background {
                    RoundedRectangle(cornerRadius: 40)
                        .fill(AppSettings.AppBackground)
                        .stroke(Color("SecondaryTextColor").opacity(0.05), style: StrokeStyle(lineWidth: 0.5))
                        .padding(-10)
                        .padding(.horizontal, -5)
                        .shadow(
                            color: Color(white: scheme == .light ? 0.8 : 0.2).opacity(scheme == .dark ? 0 : 0.1),
                            radius: 4,
                            x: 0,
                            y: 4
                        )
                }
                .padding(10)
                .padding(.horizontal, 5)
                .offset(y: 2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .modifier(EnergySettingsCardStyle())
            .overlay(alignment: .topLeading) {
                ZStack {
                    Circle()
                        .fill(Color(white: scheme == .dark ? 0.2 : 1).gradient)
                        .shadow(color: .init(white: 0.1).opacity(0.2), radius: 1, x: 2, y: 2)
                        .frame(width: 30)
                              
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15))
                        .fontWeight(.bold)                        
                        .foregroundStyle(AppSettings.burnedColor)
                        .brightness(level: scheme == .dark ? .secondary : .none)
                }
                .offset(x: -4, y: -4)
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
            .animation(.snappy, value: AppSettings.dataSource)
            
            VStack(spacing: 12) {
                (dynamicType.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .lastTextBaseline))) {
                    Text(AppSettings.weightGoal == .lose ? "Calorie Deficit" : "Calorie Surplus")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .animation(.default, value: AppSettings.weightGoal)
                        .fixedSize(horizontal: !dynamicType.isAccessibilitySize, vertical: true)
                    
                    if !dynamicType.isAccessibilitySize { Spacer() }
                    
                    HStack(alignment: .lastTextBaseline) {
                        TextField(String("0"), value: $AppSettings.balanceGoal, format: .number)
                            .focused($focusedField, equals: .balance)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .offset(x: 3)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .underline()
                            .onChange(of: AppSettings.balanceGoal) {
                                AppSettings.balanceGoal = abs(AppSettings.balanceGoal)
                            }
                    
                        EnergyUnitLabel()
                    }
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(.horizontal, 15)

                
                (dynamicType.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .lastTextBaseline))) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("Eating goal")
                            .foregroundStyle(Color("TextColor"))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if AppSettings.maxEatingEnergy() <= 0 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.red.gradient)
                                .offset(y: -1)
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    
                    if !dynamicType.isAccessibilitySize { Spacer() }
                    
                    HStack(alignment: .lastTextBaseline) {
                        Text("\(AppSettings.maxEatingEnergy())")
                            .lineLimit(1)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("TextColor"))
                            .offset(x: 3)

                        EnergyUnitLabel()
                    }
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .frame(minHeight: 20)
                .background {
                    RoundedRectangle(cornerRadius: 40)
                        .fill(AppSettings.AppBackground)
                        .stroke(Color("SecondaryTextColor").opacity(0.05), style: StrokeStyle(lineWidth: 0.5))
                        .padding(-10)
                        .padding(.horizontal, -5)
                        .shadow(
                            color: Color(white: scheme == .light ? 0.8 : 0.2).opacity(scheme == .dark ? 0 : 0.1),
                            radius: 4,
                            x: 0,
                            y: 4
                        )
                }
                .padding(10)
                .padding(.horizontal, 5)
                .offset(y: 2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .modifier(EnergySettingsCardStyle())
            .overlay(alignment: .topLeading) {
                ZStack {
                    Circle()
                        .fill(Color(white: scheme == .dark ? 0.2 : 1).gradient)
                        .shadow(color: .init(white: 0.1).opacity(0.2), radius: 1, x: 2, y: 2)
                        .frame(width: 30)
                              
                    Image(systemName: "fork.knife")
                        .font(.system(size: 13))
                        .fontWeight(.bold)                        
                        .foregroundStyle(AppSettings.consumedColor)
                        .brightness(level: scheme == .dark ? .secondary : .none)
                }
                .offset(x: -4, y: -4)
            }
            .padding(.horizontal, 40)
            .animation(.snappy, value: AppSettings.dataSource)
        }
        .task(id: EstimateKey(
            source: AppSettings.dataSource.rawValue,
            unit: AppSettings.energyUnit.rawValue,
            revision: healthDataMode.revision
        )) {
            await AppSettings.updateShow()
        }
    }

    private struct EstimateKey: Hashable {
        let source: Int
        let unit: String
        let revision: String
    }

}

/// Resting or active calorie control for the selected energy source.
private struct BurnedEnergyInputRow: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var settings: Settings

    private let kind: BurnedEnergyKind
    private let usesCustomEnergy: Bool
    private let focusedField: FocusState<Field?>.Binding

    init(_ kind: BurnedEnergyKind, focusedField: FocusState<Field?>.Binding, usesCustomEnergy: Bool) {
        self.kind = kind
        self.usesCustomEnergy = usesCustomEnergy
        self.focusedField = focusedField
    }

    var body: some View {
        (dynamicType.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .lastTextBaseline))) {
            HStack(spacing: 8) {
                Text(title)
                    .foregroundStyle(Color("TextColor"))

                if !isValid {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red.gradient)
                        .offset(y: -1)
                }
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .fixedSize(horizontal: !dynamicType.isAccessibilitySize, vertical: true)

            if !dynamicType.isAccessibilitySize { Spacer() }

            HStack(alignment: .lastTextBaseline) {
                if usesCustomEnergy {
                    TextField(String("0"), value: customValue, format: .number)
                        .focused(focusedField, equals: .active)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(dynamicType.isAccessibilitySize ? .leading : .trailing)
                        .frame(maxWidth: .infinity, alignment: dynamicType.isAccessibilitySize ? .leading : .trailing)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("TextColor"))
                        .offset(x: 3)
                        .underline()
                        .onChange(of: customValue.wrappedValue) {
                            customValue.wrappedValue = abs(customValue.wrappedValue)
                        }
                } else {
                    Text("\(healthValue)")
                        .frame(
                            width: dynamicType.isAccessibilitySize ? nil : 50,
                            alignment: dynamicType.isAccessibilitySize ? .leading : .trailing
                        )
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("TextColor"))
                        .offset(x: 3)
                        .opacity(0.6)
                }

                EnergyUnitLabel()
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

}

extension BurnedEnergyInputRow {

    private var title: LocalizedStringKey {
        switch kind {
            case .resting: "Resting Calories"
            case .active: "Active Calories"
        }
    }

    private var isValid: Bool {
        switch kind {
            case .resting: settings.isPassiveValid
            case .active: settings.isActiveValid
        }
    }

    private var customValue: Binding<Int> {
        switch kind {
            case .resting: $settings.customCalPassive
            case .active: $settings.customCalActive
        }
    }

    private var healthValue: Int {
        switch kind {
            case .resting: settings.showResting
            case .active: settings.showActive
        }
    }

}

/// Energy unit shown beside calorie settings values.
private struct EnergyUnitLabel: View {

    @EnvironmentObject private var settings: Settings

    var body: some View {
        Text(verbatim: settings.energyUnit == .kJ ? "kJ" : "kcal")
            .font(.caption)
            .fontWeight(.thin)
            .fontDesign(.rounded)
            .foregroundStyle(Color("TextColor"))
            .padding(.leading, 4)
    }

}

/// Inset appearance shared by the energy settings cards.
private struct EnergySettingsCardStyle: ViewModifier {

    @Environment(\.colorScheme) private var scheme: ColorScheme

    @EnvironmentObject private var settings: Settings

    func body(content: Content) -> some View {

        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        .shadow(.inner(
                            color: scheme == .dark
                                ? Color(white: 0.5).opacity(0.2)
                                : Color(red: 197/255, green: 197/255, blue: 197/255).opacity(0.5),
                            radius: 2,
                            x: 2,
                            y: 2
                        ))
                        .shadow(.inner(
                            color: scheme == .dark ? Color(white: 0.2).opacity(0.2) : Color.white,
                            radius: 2,
                            x: -2,
                            y: -2
                        ))
                    )
                    .foregroundColor(settings.CardBackground)
            )
            .shadow(
                color: Color(white: scheme == .light ? 0.8 : 0).opacity(scheme == .light ? 0.2 : 0),
                radius: 4,
                x: 0,
                y: 4
            )
    }

}

/// Selects which burned calorie input the shared row controls.
private enum BurnedEnergyKind {

    case resting
    case active

}

#Preview {
    NavigationView {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
