import SwiftUI

/// Composes the dashboard controls and their toolbar placement.
struct DashboardToolbar: ToolbarContent {

    let navigation: DayPager
    @Binding var todayPageMode: PagerSelection
    @Binding var showCalendar: Bool
    @Binding var showSettings: Bool
    @Binding var currentMonth: Date
    @Binding var calendarDays: [HealthInterface]
    let controlsDisabled: Bool
    let streakColor: Color
    let selectDay: (Date) -> Void
    let onToggleTodayMode: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            TodayToolbarButton(
                navigation: navigation,
                todayPageMode: $todayPageMode,
                currentMonth: $currentMonth,
                controlsDisabled: controlsDisabled,
                selectDay: selectDay,
                onToggleTodayMode: onToggleTodayMode
            )
        }

        ToolbarItem(placement: .topBarLeading) {
            SelectedDateToolbarLabel(
                navigation: navigation,
                controlsDisabled: controlsDisabled
            )
        }
        .withoutGlassBackground()
        .keepVisibleWhenConstrained()

        if #available(iOS 26, *) {
            ToolbarItemGroup(placement: .topBarTrailing) {
                StreakToolbarButton(color: streakColor, controlsDisabled: controlsDisabled)

                if dynamicType.isAccessibilitySize {
                    DashboardToolbarActionsMenu(
                        showSettings: $showSettings,
                        toggleCalendar: toggleCalendar
                    )
                } else {
                    CalendarToolbarButton(
                        showCalendar: $showCalendar,
                        controlsDisabled: controlsDisabled,
                        toggleCalendar: toggleCalendar
                    )
                    SettingsToolbarButton(showSettings: $showSettings)
                }
            }
            .sharedBackgroundVisibility(.visible)
            .yieldToDateWhenConstrained()
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                StreakToolbarButton(color: streakColor, controlsDisabled: controlsDisabled)
            }

            ToolbarItem(placement: .topBarTrailing) {
                CalendarToolbarButton(
                    showCalendar: $showCalendar,
                    controlsDisabled: controlsDisabled,
                    toggleCalendar: toggleCalendar
                )
            }

            ToolbarItem(placement: .topBarTrailing) {
                SettingsToolbarButton(showSettings: $showSettings)
                    .padding(.trailing, 16)
            }
        }
    }

    private func toggleCalendar() {
        // Populate the grid before insertion so its first layout has every row.
        if !showCalendar {
            calendarDays = navigation.calendarPages(for: currentMonth)
        }
        withAnimation(.snappy) {
            showCalendar.toggle()
        }
    }

}

private extension ToolbarContent {

    @ToolbarContentBuilder
    func withoutGlassBackground() -> some ToolbarContent {
        if #available(iOS 26, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }

    @ToolbarContentBuilder
    func keepVisibleWhenConstrained() -> some ToolbarContent {
        if #available(iOS 27, *) {
            visibilityPriority(.high)
        } else {
            self
        }
    }

    @ToolbarContentBuilder
    func yieldToDateWhenConstrained() -> some ToolbarContent {
        if #available(iOS 27, *) {
            visibilityPriority(.low)
        } else {
            self
        }
    }

}
