import SwiftUI

/// Controls for the weight goal, energy source, and daily balance target.
struct EnergySettingsView: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var AppSettings: Settings

    @State private var healthDataMode = HealthDataMode.shared

    @FocusState var focusedField: Field?

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
                        selection: $AppSettings.weightGoal,
                        first: .lose,
                        second: .gain,
                        firstLabel: "Lose Weight",
                        secondLabel: "Gain Weight",
                        firstIcon: "arrowshape.down.fill",
                        secondIcon: "arrowshape.up.fill"
                    )
                        .frame(width: 120, height: 44)
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
                            .frame(width: 120, height: 44)
                            .accessibilityHidden(true)
                    } else {
                        IconPicker(
                            selection: $AppSettings.dataSource,
                            first: .apple,
                            second: .custom,
                            firstLabel: "Apple Health",
                            secondLabel: "Custom Data",
                            firstIcon: "heart.fill",
                            secondIcon: "pencil.and.list.clipboard"
                        )
                        .frame(width: 120, height: 44)
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

            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    BurnedEnergyInputRow(.resting, focusedField: $focusedField, usesCustomEnergy: AppSettings.usesCustomEnergy)
                        .frame(minHeight: 20)

                    BurnedEnergyInputRow(.active, focusedField: $focusedField, usesCustomEnergy: AppSettings.usesCustomEnergy)
                        .frame(minHeight: 20)
                }
                .padding(.horizontal, 12)

                (dynamicType.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .lastTextBaseline))) {
                    HStack(spacing: 12) {
                        Image(systemName: "equal")
                            .foregroundStyle(AppSettings.burnedColor)
                            .frame(width: 16)
                            .accessibilityHidden(true)

                        Text("Total Burned")
                            .foregroundStyle(Color("TextColor"))

                        if !AppSettings.isBurnedValid {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.red.gradient)
                                .offset(y: -1)
                        }
                    }
                    .font(.subheadline)
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
                            .foregroundStyle(Color("TextColor"))

                        EnergyUnitLabel()
                    }
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .modifier(EnergySettingsResultStyle())

                (dynamicType.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .lastTextBaseline))) {
                    HStack(spacing: 12) {
                        Image(systemName: AppSettings.weightGoal == .lose ? "minus" : "plus")
                            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                            .animation(reduceMotion ? nil : .default, value: AppSettings.weightGoal)
                            .foregroundStyle(Color("SecondaryTextColor"))
                            .frame(width: 16)
                            .accessibilityHidden(true)

                        Text(AppSettings.weightGoal == .lose ? "Calorie Deficit" : "Calorie Surplus")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .animation(.default, value: AppSettings.weightGoal)
                            .fixedSize(horizontal: !dynamicType.isAccessibilitySize, vertical: true)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color("TextColor"))

                    if !dynamicType.isAccessibilitySize { Spacer() }

                    HStack(alignment: .lastTextBaseline) {
                        TextField(String("0"), value: $AppSettings.balanceGoal, format: .number)
                            .focused($focusedField, equals: .balance)
                            .keyboardType(.numberPad)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
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
                .frame(minHeight: 20)
                .padding(.horizontal, 12)

                (dynamicType.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .lastTextBaseline))) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "equal")
                            .foregroundStyle(AppSettings.consumedColor)
                            .frame(width: 16)
                            .accessibilityHidden(true)

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
                .modifier(EnergySettingsResultStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .fontWeight(.semibold)
            .background(AppSettings.CardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(EnergySettingsCardEdges().allowsHitTesting(false))
            .padding(.horizontal, 40)
            .padding(.top, 10)
            .animation(.snappy, value: AppSettings.dataSource)
        }
        .task(id: EstimateKey(
            source: AppSettings.dataSource.rawValue,
            unit: AppSettings.energyUnit.rawValue,
            revision: HealthRepository.shared.revision
        )) {
            await AppSettings.updateShow()
        }
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
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .foregroundStyle(Color("SecondaryTextColor"))
                    .frame(width: 16)
                    .opacity(kind == .resting ? 0 : 1)
                    .accessibilityHidden(true)

                Text(title)

                if !isValid {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red.gradient)
                        .offset(y: -1)
                }
            }
            .font(.subheadline)
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
                        .foregroundStyle(Color("SecondaryTextColor"))
                        .offset(x: 3)
                }

                EnergyUnitLabel()
            }
        }
        .foregroundStyle(Color("TextColor"))
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

/// Results use the inset treatment shared by the original calorie cards.
private struct EnergySettingsResultStyle: ViewModifier {

    @EnvironmentObject private var settings: Settings

    func body(content: Content) -> some View {
        content
            .frame(minHeight: 20)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(settings.AppBackground, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
    }

}

/// Inset edge shading around the complete calculation card.
private struct EnergySettingsCardEdges: View {

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                (scheme == .dark ? Color.black : Color.white)
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
            .blendMode(scheme == .dark ? .screen : .multiply)
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

extension EnergySettingsView {

    private struct EstimateKey: Hashable {
        let source: Int
        let unit: String
        let revision: String
    }

}

#Preview {
    NavigationView {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
