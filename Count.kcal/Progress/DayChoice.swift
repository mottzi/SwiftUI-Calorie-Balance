import Foundation

/// A user's decision about one day's calorie summary.
enum DayChoice: String, CaseIterable, Sendable {
    case automatic
    case excluded
    case fasting
}

/// Stable local calendar dates, independent of midnight's UTC offset.
enum DayKey {

    static func make(_ date: Date, calendar: Calendar = .current) -> String {

        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let components = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }

}
