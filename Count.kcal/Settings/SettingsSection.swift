import SwiftUI

/// A native list section using the dashboard card's header and appearance.
struct SettingsSection<Content: View>: View {
    private let title: LocalizedStringKey
    private let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Section {
            content
        } header: {
            CardHeader(title: title, secondaryTitle: nil)
                .textCase(nil)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
        .listSectionSeparator(.hidden)
    }
}
