import SwiftUI

/// Returns to today or switches between today's two dashboard pages.
struct TodayToolbarButton: View {

    let navigation: DayPager
    @Binding var todayPageMode: PagerSelection
    @Binding var currentMonth: Date
    let controlsDisabled: Bool
    let selectDay: (Date) -> Void

    var body: some View {
        Button(action: selectToday) {
            Image(
                systemName: !isTodaySelected
                    ? "arrow.turn.down.left"
                    : todayPageMode == .first ? "sun.min.fill" : "moon.stars.fill"
            )
            .foregroundStyle(Color("TextColor"))
            .contentTransition(.symbolEffect(.replace))
            .fontWeight(.medium)
            .frame(width: symbolWidth)
        }
        .padding(.leading, leadingPadding)
        .disabled(controlsDisabled)
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

    private func selectToday() {
        if !isTodaySelected {
            let now = Date.now
            selectDay(now)
            if !Calendar.current.isDate(currentMonth, equalTo: now, toGranularity: .month) {
                withAnimation(.snappy) { currentMonth = now }
            }
        } else {
            withAnimation(.snappy) {
                todayPageMode = todayPageMode == .first ? .second : .first
            }
        }
    }

}
