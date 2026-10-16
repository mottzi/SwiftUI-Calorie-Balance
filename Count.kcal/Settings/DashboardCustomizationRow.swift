import SwiftUI

/// Opens the dashboard card ordering settings.
struct DashboardCustomizationRow: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        NavigationLink {
            DashboardSettingsPage()
                .environmentObject(settings)
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Card order")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("TextColor"))

                    Text("Daily cards, macros, and progress")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryTextColor"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("SecondaryTextColor"))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
