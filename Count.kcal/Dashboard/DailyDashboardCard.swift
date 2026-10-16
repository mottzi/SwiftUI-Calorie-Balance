import SwiftUI

enum DailyDashboardCard: String, CaseIterable, Identifiable {
    case calories, nutrients, steps

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .calories: "Calories"
        case .nutrients: "Nutrients"
        case .steps: "Steps"
        }
    }

    /// Keep known cards once and append any missing cards in their default order.
    static func orderedCards(from storedValue: String) -> [Self] {
        let saved = storedValue.split(separator: ",").compactMap { Self(rawValue: String($0)) }
        return (saved + allCases).reduce(into: []) { cards, card in
            if !cards.contains(card) { cards.append(card) }
        }
    }
}

extension Settings {
    var dailyCards: [DailyDashboardCard] {
        get { DailyDashboardCard.orderedCards(from: dailyCardOrder) }
        set { dailyCardOrder = newValue.map(\.rawValue).joined(separator: ",") }
    }

    func moveDailyCards(from source: IndexSet, to destination: Int) {
        var cards = dailyCards
        cards.move(fromOffsets: source, toOffset: destination)
        dailyCards = cards
    }
}
