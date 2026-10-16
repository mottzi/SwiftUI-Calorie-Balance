import SwiftUI

/// Shared row identity and value mapping for the iPhone dashboard and widgets.
enum MacroNutrient: String, CaseIterable, Identifiable {
    case carbs, fats, protein

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .carbs: "Carbs"
        case .fats: "Fats"
        case .protein: "Protein"
        }
    }

    var shortTitle: LocalizedStringKey {
        switch self {
        case .carbs: "C"
        case .fats: "F"
        case .protein: "P"
        }
    }

    func consumed(in data: HealthData) -> Int {
        switch self {
        case .carbs: data.carbs
        case .fats: data.fats
        case .protein: data.protein
        }
    }

    @MainActor
    func goal(in settings: Settings) -> Int {
        switch self {
        case .carbs: settings.carbsGoal
        case .fats: settings.fatsGoal
        case .protein: settings.proteinGoal
        }
    }

    static func orderedMacros(from storedValue: String) -> [Self] {
        let saved = storedValue.split(separator: ",").compactMap { Self(rawValue: String($0)) }
        return (saved + allCases).reduce(into: []) { macros, macro in
            if !macros.contains(macro) { macros.append(macro) }
        }
    }
}

extension Settings {
    var macros: [MacroNutrient] {
        get { MacroNutrient.orderedMacros(from: macroOrder) }
        set { macroOrder = newValue.map(\.rawValue).joined(separator: ",") }
    }

    func moveMacros(from source: IndexSet, to destination: Int) {
        var order = macros
        order.move(fromOffsets: source, toOffset: destination)
        macros = order
    }
}
