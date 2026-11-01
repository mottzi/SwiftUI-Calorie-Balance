import Foundation

@MainActor
/// Uses the dashboard's full streak calculation and saved excluded days.
enum SharingStreakBuilder {
    static func summary(_ streak: Streak, settings: Settings) -> CalorieCardSnapshot.StreakSummary? {
        guard streak.hasLoadedCount, !settings.hideCalorieStatusIcons else { return nil }
        return .init(days: streak.streaks, color: CalorieCardSnapshotBuilder.adaptive(
            settings.weightGoal == .lose ? settings.burnedColor : settings.consumedColor
        ))
    }

    static func snapshot(_ streak: CalorieCardSnapshot.StreakSummary?, settings: Settings,
                         now: Date = .now) -> CalorieCardSnapshot {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        var snapshot = CalorieCardSnapshot(
            senderLocalDate: CalorieCardSnapshot.localDate(for: start, calendar: calendar),
            timeZoneIdentifier: calendar.timeZone.identifier, dayStart: start,
            dayEnd: calendar.date(byAdding: .day, value: 1, to: start)!, capturedAt: now,
            now: .init(energy: EnergyBalance(active: 0, resting: 0, consumed: 0), visibleGoalReached: nil),
            midnight: nil, energyUnit: .kcal, appearance: CalorieCardSnapshotBuilder.appearance(settings: settings)
        )
        snapshot.streak = streak
        return snapshot
    }

    static func build(repository: HealthRepository, settings: Settings, choices: [StoredDayChoice],
                      sampleData: Bool) async -> CalorieCardSnapshot.StreakSummary? {
        guard !settings.hideCalorieStatusIcons else { return nil }
        let policy = HealthSnapshotPolicy(settings: settings)
        let revision = repository.revision
        let day = Calendar.current.startOfDay(for: .now)
        let streak = Streak(repository: repository, settings: settings)
        streak.updateDayChoices(AppDatabase.choices(choices, sampleData: sampleData))
        await streak.updateStreaks()
        guard !Task.isCancelled, streak.hasLoadedCount, !settings.hideCalorieStatusIcons,
              policy == HealthSnapshotPolicy(settings: settings), repository.revision == revision,
              Calendar.current.isDateInToday(day) else { return nil }
        return summary(streak, settings: settings)
    }
}
