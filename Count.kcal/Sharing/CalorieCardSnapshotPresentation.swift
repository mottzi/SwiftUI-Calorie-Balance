import SwiftUI

extension CalorieCardSnapshot {

    /// Gregorian calendar in the time zone used to capture this sender's date.
    var senderCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
        return calendar
    }

    /// Localized sender date that cannot move into a different recipient day.
    func dayTitle(now: Date = .now, locale: Locale = .current) -> LocalizedStringResource {

        let calendar = senderCalendar
        let format = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale,
                                      calendar: calendar, timeZone: calendar.timeZone)
        let date = dayStart.formatted(format)
        if calendar.isDate(dayStart, inSameDayAs: now) {
            return LocalizedStringResource("Today", locale: locale)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(dayStart, inSameDayAs: yesterday) {
            return LocalizedStringResource("Yesterday", locale: locale)
        }
        return LocalizedStringResource("sharing.card.date", defaultValue: "\(date)", locale: locale)
    }

}

extension CalorieCardSnapshot.AdaptiveColor {

    /// Resolves the sender's color for the active appearance.
    func color(in scheme: ColorScheme) -> Color {
        let rgba = scheme == .dark ? dark : light
        return Color(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.opacity)
    }

}

