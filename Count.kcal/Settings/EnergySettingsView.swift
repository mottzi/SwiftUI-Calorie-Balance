import SwiftUI

/// Controls for the weight goal, energy source, and daily balance target.
struct EnergySettingsView: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var AppSettings: Settings

    @State private var healthDataMode = HealthDataMode.shared

    @FocusState var focusedField: Field?

    private let cardSpacing: CGFloat = 14

    var body: some View {
        VStack(spacing: cardSpacing) {
            (dynamicType.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .center, spacing: cardSpacing))
                : AnyLayout(HStackLayout(alignment: .bottom, spacing: 0))) {
                if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }

                VStack(spacing: 12) {
                    Text("I want to...")
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .foregroundStyle(Color("TextColor"))

                    SettingsIconPicker(
                        selection: $AppSettings.weightGoal,
                        first: .lose,
                        second: .gain,
                        firstLabel: "Lose Weight",
                        secondLabel: "Gain Weight",
                        firstIcon: "arrowshape.down.fill",
                        secondIcon: "arrowshape.up.fill"
                    )
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

                if !dynamicType.isAccessibilitySize { Spacer(minLength: cardSpacing) }

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
                        SettingsIconPicker(
                            selection: $AppSettings.dataSource,
                            first: .apple,
                            second: .custom,
                            firstLabel: "Apple Health",
                            secondLabel: "Custom Data",
                            firstIcon: "heart.fill",
                            secondIcon: "pencil.and.list.clipboard",
                            firstSelectedColor: .pink
                        )
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

                if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, dynamicType.isAccessibilitySize ? 16 : 0)

            VStack(spacing: 22) {
                BurnedEnergyCard(focusedField: $focusedField)
                EatingGoalCard(focusedField: $focusedField)
            }
            .padding(.horizontal, 40)
            .padding(.top, 18)
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

/// Two accessible buttons styled like the original Settings control.
private struct SettingsIconPicker<Selection: Hashable>: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    @Binding var selection: Selection

    let first: Selection
    let second: Selection
    let firstLabel: LocalizedStringKey
    let secondLabel: LocalizedStringKey
    let firstIcon: String
    let secondIcon: String
    var firstSelectedColor = Color(white: 0.1)

    private let track = RoundedRectangle(cornerRadius: 6)

    var body: some View {
        HStack(spacing: 0) {
            segment(first, label: firstLabel, icon: firstIcon, selectedColor: firstSelectedColor)
            segment(second, label: secondLabel, icon: secondIcon, selectedColor: Color(white: 0.1))
        }
        .buttonStyle(.plain)
        .frame(width: 100, height: 35)
        .background {
            GeometryReader { geometry in
                track
                    .fill(Color("IconPickerSelected").brighten(scheme == .light ? 0.1 : 0))
                    .padding(.vertical, 2)
                    .padding(selection == first ? .leading : .trailing, 2)
                    .frame(width: geometry.size.width / 2)
                    .frame(maxWidth: .infinity, alignment: selection == first ? .leading : .trailing)
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
        .background(Color("IconPickerBackground").opacity(scheme == .light ? 0.2 : 1), in: track)
        .animation(reduceMotion ? nil : .spring(duration: 0.3), value: selection)
        .accessibilityElement(children: .contain)
    }

    private func segment(
        _ value: Selection,
        label: LocalizedStringKey,
        icon: String,
        selectedColor: Color
    ) -> some View {
        let isSelected = selection == value

        return Button {
            selection = value
        } label: {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .fontWeight(isSelected ? .heavy : .regular)
                .foregroundStyle((isSelected ? selectedColor : Color(white: 0.3)).gradient)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

}

private struct BurnedEnergyCard: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var settings: Settings

    let focusedField: FocusState<Field?>.Binding

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 20) {
                BurnedEnergyInputRow(.resting, focusedField: focusedField, usesCustomEnergy: settings.usesCustomEnergy)
                    .frame(minHeight: 20)

                BurnedEnergyInputRow(.active, focusedField: focusedField, usesCustomEnergy: settings.usesCustomEnergy)
                    .frame(minHeight: 20)
            }
            .padding(.top, 6)
            .padding(.horizontal, 15)

            (dynamicType.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .lastTextBaseline))) {
                HStack(spacing: 8) {
                    Text("Total Burned")
                        .foregroundStyle(Color("TextColor"))

                    if !settings.isBurnedValid {
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
                        \(settings.usesCustomEnergy
                            ? (settings.customCalActive + settings.customCalPassive)
                            : (settings.showActive + settings.showResting))
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
        }
        .modifier(EnergyCalculationCardStyle(symbol: "bolt.fill", symbolSize: 15, tint: settings.burnedColor))
        .animation(.snappy, value: settings.dataSource)
    }

}

private struct EatingGoalCard: View {

    @Environment(\.dynamicTypeSize) private var dynamicType
    @EnvironmentObject private var settings: Settings

    let focusedField: FocusState<Field?>.Binding

    var body: some View {
        VStack(spacing: 12) {
            (dynamicType.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .lastTextBaseline))) {
                Text(settings.weightGoal == .lose ? "Calorie Deficit" : "Calorie Surplus")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .animation(.default, value: settings.weightGoal)
                    .fixedSize(horizontal: !dynamicType.isAccessibilitySize, vertical: true)
                    .font(.subheadline)
                    .foregroundStyle(Color("TextColor"))

                if !dynamicType.isAccessibilitySize { Spacer() }

                HStack(alignment: .lastTextBaseline) {
                    TextField(String("0"), value: $settings.balanceGoal, format: .number)
                        .focused(focusedField, equals: .balance)
                        .keyboardType(.numberPad)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline)
                        .foregroundStyle(Color("TextColor"))
                        .offset(x: 3)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .underline()
                        .onChange(of: settings.balanceGoal) {
                            settings.balanceGoal = abs(settings.balanceGoal)
                        }

                    EnergyUnitLabel()
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .frame(minHeight: 20)
            .padding(.horizontal, 15)

            (dynamicType.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .lastTextBaseline))) {
                HStack(spacing: 8) {
                    Text("Eating goal")
                        .foregroundStyle(Color("TextColor"))
                        .fixedSize(horizontal: false, vertical: true)

                    if settings.maxEatingEnergy() <= 0 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.red.gradient)
                            .offset(y: -1)
                    }
                }
                .font(.subheadline)
                .fontWeight(.semibold)

                if !dynamicType.isAccessibilitySize { Spacer() }

                HStack(alignment: .lastTextBaseline) {
                    Text("\(settings.maxEatingEnergy())")
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
        .modifier(EnergyCalculationCardStyle(symbol: "fork.knife", symbolSize: 13, tint: settings.consumedColor))
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

                if !isValid {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red.gradient)
                        .offset(y: -1)
                }
            }
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)

            if !dynamicType.isAccessibilitySize { Spacer(minLength: 0) }

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
            .fixedSize()
            .padding(.leading, 4)
    }

}

/// Results use the inset treatment shared by the original calorie cards.
private struct EnergySettingsResultStyle: ViewModifier {

    @EnvironmentObject private var settings: Settings

    func body(content: Content) -> some View {
        content
            .frame(minHeight: 20)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(settings.AppBackground, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
    }

}

/// Shared frame and corner badge for the two calorie calculation cards.
private struct EnergyCalculationCardStyle: ViewModifier {

    @Environment(\.colorScheme) private var scheme

    let symbol: String
    let symbolSize: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        content
            .padding(20)
            .fontWeight(.semibold)
            .modifier(EnergySettingsCardStyle())
            .overlay(alignment: .topLeading) {
                Image(systemName: symbol)
                    .font(.system(size: symbolSize, weight: .bold))
                    .foregroundStyle(tint)
                    .brightness(level: scheme == .dark ? .secondary : .none)
                    .frame(width: 30, height: 30)
                    .background {
                        Circle()
                            .fill(Color(white: scheme == .dark ? 0.2 : 1).gradient)
                            .shadow(color: Color(white: 0.1).opacity(0.2), radius: 1, x: 2, y: 2)
                    }
                    .offset(x: -4, y: -4)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
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
