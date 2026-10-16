import SwiftUI

/// Rows in the page's List, with stable identities and native reorder controls.
struct SettingsReorderRows<Item: Identifiable, Row: View>: View {
    @EnvironmentObject private var settings: Settings

    let order: KeyPath<Settings, [Item]>
    let move: (IndexSet, Int) -> Void
    @ViewBuilder let row: (Item) -> Row

    private var items: [Item] { settings[keyPath: order] }

    var body: some View {
        ForEach(items) { item in
            row(item)
                .font(.subheadline.weight(.semibold))
                .listRowBackground(SettingsReorderRowBackground(itemID: item.id, order: order))
                .accessibilityActions {
                    if let index = items.firstIndex(where: { $0.id == item.id }) {
                        if index > 0 {
                            Button("Move up") {
                                move(IndexSet(integer: index), index - 1)
                            }
                        }
                        if index < items.count - 1 {
                            Button("Move down") {
                                move(IndexSet(integer: index), index + 2)
                            }
                        }
                    }
                }
        }
        .onMove(perform: move)
    }
}
