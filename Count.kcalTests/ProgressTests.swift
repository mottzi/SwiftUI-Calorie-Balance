import Foundation
import HealthKit
import Testing
import Dependencies
import SQLiteData
@testable import Count_kcal

struct ProgressTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return calendar
    }()

    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 28))!
    }

    @Test func missingFoodAndZeroActivityAreDifferent() {
        let day = day(1, food: 0)
        #expect(DayEligibility.resolve(day, choice: .automatic) == .missingFood)
        #expect(DayEligibility.resolve(day, choice: .fasting) == .fasting)
        #expect(DayEligibility.resolve(self.day(1), choice: .automatic) == .included)
        #expect(DayEligibility.resolve(self.day(1, food: 0.1), choice: .automatic) == .included)
        #expect(DayEligibility.resolve(self.day(1, food: 0.1), choice: .fasting) == .fastingConflict)
    }

    @Test func customEnergyDoesNotRequireWatchRestingSamples() {
        let custom = ProgressDay(date: date(1), active: 2000, resting: 0, food: 1700, usesCustomEnergy: true)
        let measured = ProgressDay(date: date(1), active: 2000, resting: 0, food: 1700)
        #expect(DayEligibility.resolve(custom, choice: .automatic) == .included)
        #expect(DayEligibility.resolve(measured, choice: .automatic) == .missingEnergy)
    }

    @MainActor
    @Test func energyQueryFailureCannotCreateAFalseFastingDeficit() async {
        let history = ProgressHistory()
        await history.refresh(repository: HealthRepository(source: FailedEnergySource()), settings: .shared)
        #expect(history.energyFailed)
        #expect(!history.weightFailed)
        #expect(history.energy.isEmpty)
        #expect(history.weights.count == 1)
        let summary = history.summary(for: .week, choices: [key(1): .fasting])
        #expect(summary.averageDeficit == nil)
    }

    @Test func fastingNeverOverridesFoodOrMissingEnergy() {
        #expect(DayEligibility.resolve(day(1), choice: .fasting) == .fastingConflict)
        #expect(DayEligibility.resolve(day(1, food: 0, resting: 0), choice: .fasting) == .missingEnergy)
        #expect(DayEligibility.resolve(day(1), choice: .excluded) == .excluded)
    }

    @Test func surplusOffsetsDeficitAndTodayStaysOut() {
        let days = [day(1, food: 1700), day(2, food: 2300), day(0, food: 1)]
        let summary = summary(energy: days)
        #expect(summary.includedDays == 2)
        #expect(summary.averageDeficit == 0)
    }

    @Test func missingDaysDoNotDiluteTheAverage() {
        let summary = summary(energy: [day(1), day(2), day(3, food: 0), day(4, resting: 0)])
        #expect(summary.includedDays == 2)
        #expect(summary.averageDeficit == 300)
    }

    @Test func exclusionsPersistWhileAutomaticGapsCanResolve() {
        let choices = [key(1): DayChoice.excluded]
        let before = summary(energy: [day(1), day(2), day(3, food: 0)], choices: choices)
        let after = summary(energy: [day(1), day(2), day(3)], choices: choices)
        #expect(before.includedDays == 1 && before.averageDeficit == nil)
        #expect(after.includedDays == 2 && after.averageDeficit == 300)
    }

    @Test func fastingConflictDoesNotSilentlyChangeTheChoice() {
        let choices = [key(1): DayChoice.fasting]
        let before = summary(energy: [day(1, food: 0), day(2)], choices: choices)
        let after = summary(energy: [day(1), day(2)], choices: choices)
        #expect(before.includedDays == 2 && before.averageDeficit == 1150)
        #expect(after.days.first?.eligibility == .fastingConflict)
        #expect(after.averageDeficit == nil)
        #expect(choices[key(1)] == .fasting)
    }

    @Test func weightChangeUsesUnroundedDailyMeansAndIgnoresCalorieExclusions() {
        let weights = [date(1): 79.63, date(2): 79.61, date(8): 80.21, date(9): 80.23]
        let summary = summary(energy: [day(1), day(2)], weights: weights, choices: [key(1): .excluded])
        #expect(abs(summary.weightChange! + 0.6) < 0.00001)
        #expect(summary.currentWeightDays == 2 && summary.previousWeightDays == 2)
        #expect(summary.includedDays == 1)
    }

    @Test func sparseWeightPeriodsHaveNoComparison() {
        #expect(summary(weights: [date(1): 79, date(8): 80, date(9): 81]).weightChange == nil)
        #expect(summary(weights: [date(1): 79, date(2): 80, date(8): 81]).weightChange == nil)
    }

    @Test func monthUsesConsecutiveThirtyDayPeriods() {
        let weights = Dictionary(uniqueKeysWithValues: (1...61).map { (date($0), $0 <= 30 ? 79.6 : 80.2) })
        let summary = summary(period: .month, energy: (0...31).map { day($0) }, weights: weights)
        #expect(summary.includedDays == 30)
        #expect(summary.currentWeightDays == 30 && summary.previousWeightDays == 30)
        #expect(abs(summary.weightChange! + 0.6) < 0.00001)
    }

    @Test func calendarPeriodsSurviveDaylightSavingAndDifferentCalendars() {
        let interval = ProgressPeriod.week.interval(endingBefore: today, calendar: calendar)
        #expect(calendar.dateComponents([.day], from: interval.start, to: interval.end).day == 7)
        #expect(interval.duration == 7 * 86400 + 3600)
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar.timeZone
        #expect(DayKey.make(today, calendar: buddhist) == "2026-10-28")
        #expect(DayKey.make(today, calendar: calendar) == "2026-10-28")
    }

    @Test func invalidNumbersNeverEnterAnAverage() {
        #expect(DayEligibility.resolve(day(1, food: .nan), choice: .automatic) == .missingFood)
        #expect(DayEligibility.resolve(day(1, resting: .infinity), choice: .automatic) == .missingEnergy)
    }

    private func date(_ age: Int) -> Date {
        calendar.date(byAdding: .day, value: -age, to: today)!
    }

    private func key(_ age: Int) -> String { DayKey.make(date(age), calendar: calendar) }

    private func day(_ age: Int, food: Double = 1700, resting: Double = 2000) -> ProgressDay {
        ProgressDay(date: date(age), active: 0, resting: resting, food: food)
    }

    private func summary(
        period: ProgressPeriod = .week,
        energy: [ProgressDay] = [],
        weights: [Date: Double] = [:],
        choices: [String: DayChoice] = [:]
    ) -> ProgressSummary {
        ProgressSummary(period: period, today: today, energy: energy, weights: weights, choices: choices, calendar: calendar)
    }

}

struct DayChoiceStorageTests {

    @Test func choicesSurviveReopeningAndRestoreRemovesOnlyThatDay() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appending(path: "test.sqlite").path
        let today = Calendar.current.startOfDay(for: Date.now)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        try withDependencies {
            $0.defaultDatabase = try AppDatabase.makeDatabase(path: path)
        } operation: {
            try AppDatabase.setChoice(.excluded, for: today, sampleData: false)
            try AppDatabase.setChoice(.fasting, for: yesterday, sampleData: false)
            try AppDatabase.setChoice(.fasting, for: today, sampleData: true)
        }

        let reopened = try AppDatabase.makeDatabase(path: path)
        var records = try reopened.read { try StoredDayChoice.fetchAll($0) }
        #expect(AppDatabase.choices(records, sampleData: false)[DayKey.make(today)] == .excluded)
        #expect(AppDatabase.choices(records, sampleData: true)[DayKey.make(today)] == .fasting)
        try withDependencies { $0.defaultDatabase = reopened } operation: {
            try AppDatabase.setChoice(.automatic, for: today, sampleData: false)
        }
        records = try reopened.read { try StoredDayChoice.fetchAll($0) }
        #expect(records.count == 2)
        #expect(AppDatabase.choices(records, sampleData: false)[DayKey.make(today)] == nil)
        #expect(AppDatabase.choices(records, sampleData: false)[DayKey.make(yesterday)] == .fasting)
        #expect(AppDatabase.choices(records, sampleData: true)[DayKey.make(today)] == .fasting)
    }

    @Test func invalidChoiceCannotReplaceASavedDecision() throws {
        let database = try AppDatabase.makeDatabase(path: nil)
        try database.write { db in
            try StoredDayChoice.upsert { StoredDayChoice(id: "2026-10-04", choice: "excluded") }.execute(db)
        }
        #expect(throws: (any Error).self) {
            try database.write { db in
                try StoredDayChoice.upsert { StoredDayChoice(id: "2026-10-04", choice: "bad-value") }.execute(db)
            }
        }
        let records = try database.read { try StoredDayChoice.fetchAll($0) }
        #expect(records == [StoredDayChoice(id: "2026-10-04", choice: "excluded")])
    }

}

private struct FailedEnergySource: HealthDataSource {
    func dailySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async -> [Date: Double] {
        [:]
    }
    func energySums(_ type: HKQuantityTypeIdentifier, from start: Date, to end: Date, unit: HKUnit) async throws -> [Date: Double] {
        throw CocoaError(.fileReadUnknown)
    }
    func weights(from start: Date, to end: Date, unit: HKUnit) async throws -> [WeightChartData] {
        [WeightChartData(date: start, weightAvg: 80)]
    }
    func latestWeight(before end: Date, unit: HKUnit) async throws -> (Double?, Date?) { (nil, nil) }
    func requestPermission() async -> Bool { true }
}
