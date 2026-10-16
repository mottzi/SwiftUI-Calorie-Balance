import SwiftUI

/// A compact preview of the saved layout, linked to the full editor.
struct DashboardCustomizationCard: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        Card("Dashboard") {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(cardOrder)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color("TextColor"))

                    Text(macroOrder)
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryTextColor"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

                NavigationLink {
                    DashboardSettingsPage()
                        .environmentObject(settings)
                } label: {
                    HStack(spacing: 5) {
                        Text("Edit")
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("TextColor"))
                    .fixedSize()
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit dashboard layout")
            }
        }
    }

    private var cardOrder: String {
        settings.dashboardProgressPosition.sections.flatMap { section -> [String] in
            switch section {
            case .daily:
                settings.dailyCards.map { String(localized: $0.title) }
            case .progress:
                [String(localized: "Progress")]
            }
        }
        .joined(separator: " › ")
    }

    private var macroOrder: String {
        settings.macros.map { macro in
            switch macro {
            case .carbs: String(localized: "Carbs")
            case .fats: String(localized: "Fats")
            case .protein: String(localized: "Protein")
            }
        }
        .joined(separator: " › ")
    }

}
