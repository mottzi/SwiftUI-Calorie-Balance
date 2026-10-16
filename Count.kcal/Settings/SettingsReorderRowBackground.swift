import SwiftUI

/// Native List retains backgrounds during a move, so resolve corners from live order.
struct SettingsReorderRowBackground<Item: Identifiable>: View {
    @EnvironmentObject private var settings: Settings

    let itemID: Item.ID
    let order: KeyPath<Settings, [Item]>

    var body: some View {
        let items = settings[keyPath: order]
        SettingsCardRowBackground(
            roundsTop: itemID == items.first?.id,
            roundsBottom: itemID == items.last?.id
        )
    }
}
