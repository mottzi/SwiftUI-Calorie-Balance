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
        Button(action: selectToday) {
            Image(
                systemName: !isTodaySelected
                    ? "arrow.turn.down.left"
                    : todayPageMode.selection == .first ? "sun.min.fill" : "moon.stars.fill"
            )
            .foregroundStyle(Color("TextColor"))
            .contentTransition(.symbolEffect(.replace))
            .fontWeight(.medium)
            .frame(width: symbolWidth)
        }
        .padding(.leading, leadingPadding)
        .disabled(controlsDisabled)
        .accessibilityLabel(actionLabel)
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

    private var symbolWidth: CGFloat? {
        if #available(iOS 26, *) { nil } else { 30 }
    }

    private var leadingPadding: CGFloat {
        if #available(iOS 26, *) { 0 } else { 16 }
    }

    private var actionLabel: LocalizedStringKey {
        !isTodaySelected ? "Today" : todayPageMode.selection == .first ? "Midnight" : "Now"
    }

}
