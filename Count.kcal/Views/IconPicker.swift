import SwiftUI

/// Two named choices with native selection and accessibility behavior.
struct IconPicker<Selection: Hashable>: View {

    @Binding var selection: Selection

    let first: Selection
    let second: Selection
    let firstLabel: LocalizedStringKey
    let secondLabel: LocalizedStringKey
    let firstIcon: String
    let secondIcon: String

    var body: some View {
        Picker("", selection: $selection) {
            Label(firstLabel, systemImage: firstIcon)
                .tag(first)
            Label(secondLabel, systemImage: secondIcon)
                .tag(second)
        }
        .labelStyle(.iconOnly)
        .pickerStyle(.segmented)
    }

}

enum PagerSelection: String {

    mutating func toggle() {
        self = self == .first ? .second : .first
    }

    case first
    case second

}

#Preview {
    NavigationStack {
        SettingsPage()
            .environmentObject(Settings.shared)
            .environment(HSlider())
    }
}
