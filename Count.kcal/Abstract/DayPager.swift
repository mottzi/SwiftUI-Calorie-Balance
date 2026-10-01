import Foundation
import Observation

@MainActor
@Observable
/// Calendar-day navigation and shared health models for the dashboard and charts.
final class DayPager {

    private(set) var pages: [HealthInterface]
    private(set) var weekPages: [HealthInterface] = []
    private(set) var balanceWeeks: [BalanceWeek] = []
    var dayIsScrolling = false
    var weekIsScrolling = false
    var isScrolling: Bool { dayIsScrolling || weekIsScrolling }
    var selectedDay: Date

    /// The day strip applies this intent to its own scroll-position update.
    @ObservationIgnored private(set) var animatesDayScroll = false

    @ObservationIgnored private var models: [Date: HealthInterface] = [:]

    init(past: Int, future: Int, today: Date = .now) {

        let today = Calendar.current.startOfDay(for: today)
        selectedDay = today
        pages = []

        // seed one continuous range so every page has a stable scroll target
        for offset in (-max(14, past))...max(14, future) {
            let day = Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
            pages.append(model(for: day))
        }
        updateWeek(for: today)
    }

    /// Keeps programmatic navigation intent with the selected date.
    func selectDay(_ date: Date, animated: Bool = false) {
        animatesDayScroll = animated
        selectedDay = Calendar.current.startOfDay(for: date)
    }

    /// Returns a cached model without creating one during view evaluation.
    func page(for date: Date) -> HealthInterface? {
        models[Calendar.current.startOfDay(for: date)]
    }

    /// Browsing a month fills only the model cache; it leaves the swipe range alone.
    func calendarPages(for month: Date) -> [HealthInterface] {

        let first = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: month)
        )?.weekStartDate ?? month
        let last = month.lastDayOfMonth.weekEndDate
        var calendarModels: [HealthInterface] = []
        var day = first

        // reuse dashboard models without inserting calendar dates into the pager
        while day <= last {
            calendarModels.append(model(for: day))
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return calendarModels
    }

    /// Extends the swipe range after a user swipes to an edge day.
    func ensureSelectionBuffer() {

        guard !isScrolling else { return }
        ensurePages(through: selectedDay)
        prepareBalanceWeeks(for: selectedDay)
    }

    /// Prepares buffered pages before a calendar or week selection changes.
    func ensurePagesForSelection(_ date: Date) {
        ensurePages(through: Calendar.current.startOfDay(for: date))
        prepareBalanceWeeks(for: date)
    }

    /// Seven-day groups end on Today, preserving the recent graph's layout.
    /// Calendar arithmetic keeps the boundaries correct across daylight saving.
    func balanceWeekStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let anchor = weekPages.first!.id
        let day = calendar.startOfDay(for: date)
        let distance = calendar.dateComponents([.day], from: anchor, to: day).day ?? 0
        let offset = distance >= 0 ? distance / 7 : (distance - 6) / 7
        return calendar.date(byAdding: .day, value: offset * 7, to: anchor)!
    }

    /// A week swipe selects the destination edge nearest the previous week.
    func day(inBalanceWeek start: Date) -> Date {
        let calendar = Calendar.current
        let currentStart = balanceWeekStart(for: selectedDay)
        guard start != currentStart else { return selectedDay }
        let column = start < currentStart ? 6 : 0
        let day = calendar.date(byAdding: .day, value: column, to: start)!
        return day
    }

    /// Extend the native scroll targets without replacing the week being viewed.
    private func prepareBalanceWeeks(for date: Date) {
        let calendar = Calendar.current
        let start = balanceWeekStart(for: date)
        let lower = calendar.date(byAdding: .day, value: -14, to: start)!
        let upper = calendar.date(byAdding: .day, value: 14, to: start)!
        if balanceWeeks.isEmpty {
            balanceWeeks = (-2...2).map {
                balanceWeek(startingOn: calendar.date(byAdding: .day, value: $0 * 7, to: start)!)
            }
            return
        }
        var earlier: [BalanceWeek] = []
        var first = balanceWeeks.first!.id
        while lower < first {
            first = calendar.date(byAdding: .day, value: -7, to: first)!
            earlier.append(balanceWeek(startingOn: first))
        }
        if !earlier.isEmpty { balanceWeeks.insert(contentsOf: earlier.reversed(), at: 0) }
        var last = balanceWeeks.last!.id
        while upper > last {
            last = calendar.date(byAdding: .day, value: 7, to: last)!
            balanceWeeks.append(balanceWeek(startingOn: last))
        }
    }

    private func balanceWeek(startingOn start: Date) -> BalanceWeek {
        let days = (0..<7).map { offset in
            model(for: Calendar.current.date(byAdding: .day, value: offset, to: start)!)
        }
        return BalanceWeek(id: start, days: days)
    }

    /// Moves Today forward after midnight while keeping every existing day's model stable.
    func rolloverIfNeeded(today: Date = .now) {

        let today = Calendar.current.startOfDay(for: today)
        guard weekPages.last?.id != today else { return }
        // follow the new day only if the user was viewing Today
        let wasToday = selectedDay == weekPages.last?.id
        ensurePages(through: today)
        updateWeek(for: today)
        if wasToday { selectDay(today) }
        prepareBalanceWeeks(for: selectedDay)
    }

}

extension DayPager {

    private func model(for date: Date) -> HealthInterface {

        let day = Calendar.current.startOfDay(for: date)
        if let model = models[day] { return model }
        let model = HealthInterface(.empty(for: day))
        models[day] = model
        return model
    }

    /// Inserts adjacent pages around the requested day without changing selection.
    private func ensurePages(through date: Date) {

        guard let first = pages.first?.id, let last = pages.last?.id else { return }
        // preserve existing instances while extending both ends past the requested day
        var earlier: [HealthInterface] = []
        var day = first
        let lower = Calendar.current.date(byAdding: .day, value: -14, to: date)!
        let upper = Calendar.current.date(byAdding: .day, value: 14, to: date)!
        while lower < day {
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            earlier.append(model(for: previous))
            day = previous
        }
        pages.insert(contentsOf: earlier.reversed(), at: 0)

        day = last
        while upper > day {
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: day) else { break }
            pages.append(model(for: next))
            day = next
        }
    }

    private func updateWeek(for today: Date) {

        weekPages = (0...6).reversed().map { offset in
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: today) ?? today
            return model(for: day)
        }
        balanceWeeks = []
        prepareBalanceWeeks(for: selectedDay)
    }

}

/// Stable calendar identity and shared dashboard models for a graph page.
struct BalanceWeek: Identifiable, Equatable {
    let id: Date
    let days: [HealthInterface]
}
