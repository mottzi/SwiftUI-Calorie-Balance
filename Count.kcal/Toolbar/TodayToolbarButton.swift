import SwiftUI

/// Returns to today or switches between today's two dashboard pages.
struct TodayToolbarButton: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let navigation: DayPager

    @Binding var todayPageMode: TodayPageMode
    @Binding var currentMonth: Date

    let controlsDisabled: Bool
    let selectDay: (Date) -> Void

    var body: some View {
        CalorieModeToolbarButton(
            mode: isTodaySelected ? (todayPageMode.selection == .first ? .now : .midnight) : nil,
            controlsDisabled: controlsDisabled,
            action: selectToday
        )
    }

}

extension TodayToolbarButton {

    private func selectToday() {
        if !isTodaySelected {
            let now = Date.now
            selectDay(now)
            if !Calendar.current.isDate(currentMonth, equalTo: now, toGranularity: .month) {
                withAnimation(reduceMotion ? nil : .snappy) { currentMonth = now }
            }
        } else {
            withAnimation(reduceMotion ? nil : .snappy) { todayPageMode.toggle(from: .toolbar) }
        }
    }

    private var isTodaySelected: Bool {
        navigation.selectedDay == Calendar.current.startOfDay(for: .now)
    }

}

/// The shared sun/moon control. An unselected day returns to Today.
struct CalorieModeToolbarButton: View {

    let mode: GraphMode?
    var controlsDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .foregroundStyle(Color("TextColor"))
                .contentTransition(.symbolEffect(.replace))
                .fontWeight(.medium)
                .frame(width: symbolWidth)
        }
        .padding(.leading, leadingPadding)
        .disabled(controlsDisabled)
        .accessibilityLabel(actionLabel)
    }

    private var symbolName: String {
        switch mode {
        case .now: "sun.min.fill"
        case .midnight: "moon.stars.fill"
        case nil: "arrow.turn.down.left"
        }
    }

    private var actionLabel: LocalizedStringKey {
        switch mode {
        case .now: "Midnight"
        case .midnight: "Now"
        case nil: "Today"
        }
    }

    private var symbolWidth: CGFloat? {
        if #available(iOS 26, *) { nil } else { 30 }
    }

    private var leadingPadding: CGFloat {
        if #available(iOS 26, *) { 0 } else { 16 }
    }

}
