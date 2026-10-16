import SwiftUI
import WidgetKit

struct DashboardSettingsPage: View {
    @EnvironmentObject private var settings: Settings

    var body: some View {
        GeometryReader { geometry in
            List {
                Section {
                    DashboardLayoutPreview(
                        dailyCards: settings.dailyCards,
                        macros: settings.macros,
                        progressPosition: settings.dashboardProgressPosition,
                        width: min(200, (geometry.size.width - 2 * CardMetrics.horizontalInset) * 0.5),
                        canvasWidth: geometry.size.width - 2 * CardMetrics.horizontalInset
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .environment(\.editMode, .constant(.inactive))
                    .moveDisabled(true)
                }

                DashboardOrderingControls()
            }
            .listStyle(.grouped)
            .listSectionSpacing(24)
            .contentMargins(.horizontal, CardMetrics.horizontalInset, for: .scrollContent)
            .contentMargins(.top, 0, for: .scrollContent)
            .environment(\.defaultMinListHeaderHeight, 0)
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
        }
        .background(settings.AppBackground)
        .foregroundStyle(Color("TextColor"))
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings.macroOrder) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
