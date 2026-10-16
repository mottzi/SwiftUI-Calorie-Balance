import SwiftUI
import WidgetKit

struct DashboardSettingsPage: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        List {
            DashboardOrderingControls()
        }
        .listStyle(.grouped)
        .listSectionSpacing(24)
        .contentMargins(.horizontal, CardMetrics.horizontalInset, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollContent)
        .environment(\.defaultMinListHeaderHeight, 0)
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(settings.AppBackground)
        .foregroundStyle(Color("TextColor"))
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings.macroOrder) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
