import Foundation
import Observation

@MainActor
@Observable
/// Calendar-day navigation and shared health models for the dashboard and charts.
final class DayPager {

    private(set) var pages: [HealthInterface]
    private(set) var weekPages: [HealthInterface] = []
    var selectedDay: Date

    @ObservationIgnored private var models: [Date: HealthInterface] = [:]

    init(past: Int, future: Int) {

        let today = Calendar.current.startOfDay(for: .now)
        selectedDay = today
        pages = []

        // seed one continuous range so every page has a stable scroll target
        for offset in (-max(0, past))...max(0, future) {
            let day = Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
            pages.append(model(for: day))
        }
        updateWeek(for: today)
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

        ensurePages(through: selectedDay)
    }

    /// Prepares buffered pages before a calendar or week selection changes.
    func ensurePagesForSelection(_ date: Date) {
        ensurePages(through: Calendar.current.startOfDay(for: date))
    }

    /// Moves Today forward after midnight while keeping every existing day's model stable.
    func rolloverIfNeeded() {

        let today = Calendar.current.startOfDay(for: .now)
        guard weekPages.last?.id != today else { return }
        // follow the new day only if the user was viewing Today
        let wasToday = selectedDay == weekPages.last?.id
        ensurePages(through: today)
        updateWeek(for: today)
        if wasToday { selectedDay = today }
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
        while date <= day {
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            earlier.append(model(for: previous))
            day = previous
        }
        pages.insert(contentsOf: earlier.reversed(), at: 0)

        day = last
        while date >= day {
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
    }

}
