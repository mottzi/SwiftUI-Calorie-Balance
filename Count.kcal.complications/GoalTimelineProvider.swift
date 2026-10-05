import SwiftUI
import WidgetKit

/// Daily measurements and saved goals for the nutrition and movement complications.
struct GoalComplicationEntry: TimelineEntry {

    let date: Date
    let data: HealthData
    let balanceGoal: Int
    let isLoss: Bool
    let proteinGoal: Int
    let carbsGoal: Int
    let fatsGoal: Int
    let stepsGoal: Int
    let energyUnit: String
    var isSampleData = false

    var budget: ComplicationCalorieBudget {
        ComplicationCalorieBudget(
            burned: data.midnight.burned,
            consumed: data.consumed,
            balanceGoal: balanceGoal,
            isLoss: isLoss
        )
    }

    var protein: ComplicationGoalProgress { ComplicationGoalProgress(amount: data.protein, goal: proteinGoal) }
    var carbs: ComplicationGoalProgress { ComplicationGoalProgress(amount: data.carbs, goal: carbsGoal) }
    var fats: ComplicationGoalProgress { ComplicationGoalProgress(amount: data.fats, goal: fatsGoal) }
    var steps: ComplicationGoalProgress { ComplicationGoalProgress(amount: data.steps, goal: stepsGoal) }

}

/// Shared health refresh schedule with fixed goals and repeatable gallery values.
struct GoalComplicationTimelineProvider: TimelineProvider {

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalComplicationEntry>) -> Void) {
        Task { @MainActor in
            let date = Date.now
            var goals: SavedGoals
            var revision: String
            var data: HealthData
            repeat {
                revision = HealthRepository.shared.revision
                goals = SavedGoals(settings: .shared)
                data = await HealthRepository.shared.fetchDailySnapshot(for: date, now: date)
            } while !Task.isCancelled && (
                revision != HealthRepository.shared.revision || goals != SavedGoals(settings: .shared)
            )

            let entry = GoalComplicationEntry(
                date: date,
                data: data,
                balanceGoal: goals.balance,
                isLoss: goals.isLoss,
                proteinGoal: goals.protein,
                carbsGoal: goals.carbs,
                fatsGoal: goals.fats,
                stepsGoal: goals.steps,
                energyUnit: goals.unit,
                isSampleData: data.isSampleData
            )
            let midnight = Calendar.current.nextDate(
                after: date,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            )!
            completion(Timeline(entries: [entry], policy: .after(min(date.addingTimeInterval(15 * 60), midnight))))
        }
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalComplicationEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            getTimeline(in: context) { timeline in
                completion(timeline.entries.first ?? placeholder(in: context))
            }
        }
    }

    func placeholder(in context: Context) -> GoalComplicationEntry { .preview }

}

extension GoalComplicationTimelineProvider {

    private struct SavedGoals: Equatable {

        let balance: Int
        let isLoss: Bool
        let protein: Int
        let carbs: Int
        let fats: Int
        let steps: Int
        let unit: String

        @MainActor
        init(settings: Settings) {
            balance = settings.balanceGoal
            isLoss = settings.weightGoal == .lose
            protein = settings.proteinGoal
            carbs = settings.carbsGoal
            fats = settings.fatsGoal
            steps = settings.stepsGoal
            unit = settings.energyUnit.rawValue
        }

    }

}

extension GoalComplicationEntry {

    static var preview: GoalComplicationEntry {
        let date = Date.now
        var data = HealthData.example(for: date)
        data.burnedActive = 650
        data.burnedPassive = 1400
        data.burnedPassive7 = 2300
        data.consumed = 1810
        data.protein = 106
        data.carbs = 172
        data.fats = 58
        data.steps = 7240
        return GoalComplicationEntry(
            date: date,
            data: data,
            balanceGoal: 500,
            isLoss: true,
            proteinGoal: 140,
            carbsGoal: 240,
            fatsGoal: 65,
            stepsGoal: 10000,
            energyUnit: "kcal"
        )
    }

}
