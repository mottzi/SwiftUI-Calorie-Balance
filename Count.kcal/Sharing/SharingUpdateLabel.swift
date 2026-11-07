import SwiftUI

/// Keeps relative time live without invalidating the surrounding card or screen.
struct SharingUpdateLabel: View {
    enum Style {
        case updated
        case lastShared
        case relative
    }

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    let date: Date
    var style: Style = .relative

    var body: some View {
        TimelineView(.periodic(from: date, by: 60)) { context in
            label(Text(verbatim: Self.relativeTime(
                from: date, to: context.date, locale: locale, calendar: calendar
            )))
        }
    }

    private func label(_ relativeTime: Text) -> Text {
        switch style {
        case .updated:
            Text("Updated \(relativeTime)")
        case .lastShared:
            Text("Last shared \(relativeTime)")
        case .relative:
            relativeTime.accessibilityLabel(Text("Last shared \(relativeTime)"))
        }
    }

    /// Completed minutes keep independently opened labels in step and avoid a seconds counter.
    static func relativeTime(from date: Date, to now: Date, locale: Locale, calendar: Calendar) -> String {
        let minutes = max(0, floor(now.timeIntervalSince(date) / 60))
        let reference = date.addingTimeInterval(minutes * 60)
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: reference)
    }
}
