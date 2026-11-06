import SwiftUI

/// Calorie-card snapshot builder for completed health samples and sender policy.
enum CalorieCardSnapshotBuilder {

    @MainActor
    /// Builds a snapshot only if the day's loaded values match the current health policy.
    static func build(from day: HealthInterface, settings: Settings, calendar: Calendar = .current) -> CalorieCardSnapshot?
    {
        guard day.hasCurrentSnapshot else { return nil }
        return build(sample: day.sample, settings: settings, calendar: calendar)
    }

    @MainActor
    /// Builds a snapshot from a sample and the sender's current settings.
    static func build(sample: HealthData, settings: Settings, calendar: Calendar = .current) -> CalorieCardSnapshot? {
        build(
            sample: sample,
            policy: HealthSnapshotPolicy(settings: settings),
            hidesGoalStatus: settings.hideCalorieStatusIcons,
            appearance: appearance(settings: settings),
            calendar: calendar
        )
    }

    /// Builds a supported snapshot from a sample and its fixed calculation policy.
    static func build(
        sample: HealthData,
        policy: HealthSnapshotPolicy,
        hidesGoalStatus: Bool,
        appearance: CalorieCardSnapshot.Appearance,
        calendar sourceCalendar: Calendar
    ) -> CalorieCardSnapshot? {

        guard !sample.isUnavailable, let capturedAt = sample.lastDataSync else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = sourceCalendar.timeZone
        let dayStart = calendar.startOfDay(for: sample.date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
              capturedAt >= dayStart else { return nil }
        func values(_ energy: EnergyBalance) -> CalorieCardSnapshot.ModeValues {
            .init(
                energy: energy,
                visibleGoalReached: hidesGoalStatus || energy.isEmpty ? nil
                    : energy.meetsGoal(policy.balanceGoal, isLoss: policy.isLoss)
            )
        }
        let snapshot = CalorieCardSnapshot(
            senderLocalDate: CalorieCardSnapshot.localDate(for: dayStart, calendar: calendar),
            timeZoneIdentifier: calendar.timeZone.identifier,
            dayStart: dayStart,
            dayEnd: dayEnd,
            capturedAt: capturedAt,
            now: values(sample.now),
            midnight: capturedAt < dayEnd ? values(sample.midnight) : nil,
            energyUnit: policy.energyUnit == .kcal ? .kcal : .kJ,
            appearance: appearance
        )
        return snapshot.isSupported ? snapshot : nil
    }

}

extension CalorieCardSnapshotBuilder {

    @MainActor
    /// Resolves the sender's card colors for both light and dark appearance.
    static func appearance(settings: Settings) -> CalorieCardSnapshot.Appearance {
        appearance(settings: settings, background: settings.appBackground)
    }

    @MainActor
    static func appearance(settings: Settings, background: Settings.AppBackgrounds) -> CalorieCardSnapshot.Appearance {
        .init(
            burned: adaptive(settings.burnedColor),
            consumed: adaptive(settings.consumedColor),
            cardBackground: adaptive(background.cardColor),
            graphEmpty: .init(
                light: rgba(background.graphEmptyColor(.light), scheme: .light),
                dark: rgba(background.graphEmptyColor(.dark), scheme: .dark)
            ),
            labelBackground: settings.showCalorieLabelBackgrounds
                ? adaptive(settings.calorieLabelBackground.labelBackgroundColor) : nil,
            pageBackground: adaptive(background.pageColor),
            nameColor: adaptive(settings.weightGoal == .lose ? settings.burnedColor : settings.consumedColor)
        )
    }

    @MainActor
    /// Builds light and dark variants of one color.
    static func adaptive(_ color: Color) -> CalorieCardSnapshot.AdaptiveColor {
        .init(light: rgba(color, scheme: .light), dark: rgba(color, scheme: .dark))
    }

    @MainActor
    /// Resolves a SwiftUI color into portable sRGB components.
    private static func rgba(_ color: Color, scheme: ColorScheme) -> CalorieCardSnapshot.RGBA {

        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let resolved = color.resolve(in: environment)
        return .init(
            red: Double(resolved.red),
            green: Double(resolved.green),
            blue: Double(resolved.blue),
            opacity: Double(resolved.opacity)
        )
    }

}
