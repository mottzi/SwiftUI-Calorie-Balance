import SwiftUI

/// Sender-calorie card using the local layout and no recipient calorie preferences.
struct SharedCalorieCard: View {

    var hidesGoalStatus = false

    /// Appearance used to resolve the sender's portable colors.
    @Environment(\.colorScheme) private var scheme

    /// Immutable values and appearance supplied by the sender.
    let snapshot: CalorieCardSnapshot

    /// Card mode selected by the recipient.
    let mode: GraphMode

    /// Whether values animate after a local mode selection.
    var animateNumericValues = false

    /// Shows sender values or an unavailable message for an unsupported snapshot.
    var body: some View {
        if snapshot.isSupported {
            let values = mode == .midnight ? snapshot.midnight ?? snapshot.now : snapshot.now
            CalorieCardContent(
                energy: values.energy,
                energyUnit: snapshot.energyUnit.rawValue,
                burnedColor: snapshot.color(snapshot.appearance.burned, scheme: scheme),
                consumedColor: snapshot.color(snapshot.appearance.consumed, scheme: scheme),
                graphEmptyColor: snapshot.color(snapshot.appearance.graphEmpty, scheme: scheme),
                cardBackground: snapshot.color(snapshot.appearance.cardBackground, scheme: scheme),
                visibleGoalReached: hidesGoalStatus ? nil : values.visibleGoalReached,
                labelBackground: snapshot.appearance.labelBackground.map { snapshot.color($0, scheme: scheme) },
                animateNumericValues: animateNumericValues
            )
        } else {
            Text("Card unavailable")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        }
    }

}

/// Today's received card uses the dashboard's recessed mode-switching button.
struct SharedTodayCalorieCard: View {

    var hidesGoalStatus = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var mode: GraphMode

    @State private var feedback = RecessedCardFeedback()

    let snapshot: CalorieCardSnapshot

    var body: some View {
        Button {
            feedback.activate()
            mode = mode == .now ? .midnight : .now
        } label: {
            SharedCalorieCard(hidesGoalStatus: hidesGoalStatus, snapshot: snapshot, mode: mode, animateNumericValues: true)
                .animation(reduceMotion ? nil : .smooth(duration: CalorieGraphAnimation.defaultDuration), value: mode)
                .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(RecessedCardStyle(
            background: snapshot.color(snapshot.appearance.cardBackground, scheme: scheme),
            feedback: feedback,
            pulse: 0
        ))
        .accessibilityLabel("Calories")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(mode == .now ? "Show the midnight estimate" : "Show the current balance")
        .accessibilityInputLabels(["Calories", "Calorie balance"])
    }

    private var accessibilityValue: Text {
        let values = mode == .midnight ? snapshot.midnight ?? snapshot.now : snapshot.now
        let modeTitle: LocalizedStringKey = mode == .now ? "Now" : "Midnight"
        let balanceTitle: LocalizedStringKey = values.balance == 0 ? "Balance" : values.balance > 0 ? "Deficit" : "Surplus"
        return Text("\(Text(modeTitle)). \(Text(balanceTitle)) \(abs(values.balance)) \(snapshot.energyUnit.rawValue). Burned \(values.burned) \(snapshot.energyUnit.rawValue). Eaten \(values.consumed) \(snapshot.energyUnit.rawValue).")
    }

}

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

    /// Resolves the sender's color for the active appearance.
    func color(_ adaptive: AdaptiveColor, scheme: ColorScheme) -> Color {
        let rgba = scheme == .dark ? adaptive.dark : adaptive.light
        return Color(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.opacity)
    }

}

/// Sender-local dates and streak membership, limited to the permitted seven-day view.
struct SharedCalorieWeek {
    struct Day: Identifiable {
        let id: Date
        let snapshot: CalorieCardSnapshot?
        var isInCurrentStreak = false
    }

    let calendar: Calendar
    let today: Date
    let days: [Day]

    init(snapshots: [CalorieCardSnapshot], now: Date = .now) {
        let latest = snapshots.max { $0.capturedAt < $1.capturedAt }
        let calendar = latest?.senderCalendar ?? Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        self.calendar = calendar
        self.today = today
        var days = (-SharingDateWindow.historyDayCount...0).compactMap { offset -> Day? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let label = CalorieCardSnapshot.localDate(for: date, calendar: calendar)
            let snapshot = snapshots.filter {
                $0.isSupported && $0.senderLocalDate == label && $0.energyUnit == latest?.energyUnit
            }.max { $0.capturedAt < $1.capturedAt }
            return Day(id: date, snapshot: snapshot)
        }
        // Today never contributes to the completed-day streak. Missing or hidden results break it.
        for index in days.indices.dropLast().reversed() {
            guard let snapshot = days[index].snapshot,
                  snapshot.isExcluded != true,
                  snapshot.now.consumed > 0, snapshot.now.visibleGoalReached == true else { break }
            days[index].isInCurrentStreak = true
        }
        self.days = days
    }
}

/// The dashboard chart drawing with sender values and no day-selection action.
struct SharedWeekBalanceChart: View {
    @Environment(\.colorScheme) private var scheme
    let snapshots: [CalorieCardSnapshot]

    var body: some View {
        let week = SharedCalorieWeek(snapshots: snapshots)
        WeekBalanceChartContent(
            dataPoints: week.days.map { day in
                let isToday = day.id == week.today
                let values = isToday ? day.snapshot?.midnight ?? day.snapshot?.now : day.snapshot?.now
                let energy = values?.energy ?? EnergyBalance(active: 0, resting: 0, restingRemaining: 0, consumed: 0)
                let snapshot = day.snapshot
                return .init(
                    id: day.id, energy: energy,
                    color: WeekBalanceChartContent.VBarBalanceGraph.barColor(
                        energy: energy, isToday: isToday, goalReached: values?.visibleGoalReached == true,
                        isExcluded: snapshot?.isExcluded == true,
                        burned: snapshot.map { $0.color($0.appearance.burned, scheme: scheme) } ?? .secondary,
                        consumed: snapshot.map { $0.color($0.appearance.consumed, scheme: scheme) } ?? .secondary
                    ),
                    isInCurrentStreak: day.isInCurrentStreak,
                    isLoaded: snapshot != nil
                )
            },
            selectedDay: week.today,
            calendar: week.calendar
        )
    }
}
