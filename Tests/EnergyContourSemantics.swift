import Foundation

@main
struct EnergyContourSemantics {

    static func main() {

        let start = Date(timeIntervalSince1970: 0)
        let end = start.addingTimeInterval(86400)
        let morning = start.addingTimeInterval(8 * 3600)
        let lunch = start.addingTimeInterval(12 * 3600)
        let now = start.addingTimeInterval(16 * 3600)
        let contour = EnergyContour(
            start: start,
            end: end,
            now: now,
            burned: [start: 100, morning: 800, lunch: 1100],
            consumed: [morning: 500, lunch: 900],
            estimatedBurned: 2900,
            balanceGoal: 500,
            isLoss: true
        )
        precondition(contour.current.burned == 2000 && contour.current.consumed == 1400)
        precondition(contour.budget.remaining == 1000)
        precondition(contour.current.time == contour.progress && contour.progress == 2.0 / 3)
        precondition(contour.points[1].time == 900.0 / 86400)
        precondition(contour.points.allSatisfy { $0.time <= contour.progress })
        precondition(contour.points.filter { $0.consumed == 500 }.count == 1)

        let custom = EnergyContour(
            start: start,
            end: end,
            now: now,
            burned: [morning: 9999],
            consumed: [lunch: 2500],
            estimatedBurned: 2400,
            customBurned: 2400,
            balanceGoal: 400,
            isLoss: true
        )
        precondition(custom.isBurnEstimated && custom.current.burned == 1600)
        precondition(custom.budget.remaining == -500)
        precondition(custom.points.allSatisfy { abs($0.burned - 2400 * $0.time) < 0.00001 })
        precondition(custom.current.consumed < custom.scale)

        let invalid = EnergyContour(
            start: start,
            end: end,
            now: now,
            burned: [start.addingTimeInterval(-900): 500, start: .nan, morning: -100, end: 500],
            consumed: [start: .infinity],
            estimatedBurned: .nan,
            balanceGoal: 0,
            isLoss: false
        )
        precondition(!invalid.hasData && invalid.budget.remaining == nil)
        precondition(invalid.current.burned == 0 && invalid.current.consumed == 0)
        precondition(invalid.scale > 0 && invalid.points.count >= 1)

        let completed = EnergyContour(
            start: start,
            end: end,
            now: end.addingTimeInterval(100),
            burned: [morning: 3000],
            consumed: [lunch: 3200],
            estimatedBurned: 2500,
            balanceGoal: 400,
            isLoss: false
        )
        precondition(completed.progress == 1 && completed.estimatedBurned == 3000)
        precondition(completed.budget.remaining == 200)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        let spring = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29))!
        let springEnd = calendar.date(byAdding: .day, value: 1, to: spring)!
        let shortDay = EnergyContour(
            start: spring,
            end: springEnd,
            now: spring.addingTimeInterval(11.5 * 3600),
            burned: [:],
            consumed: [:],
            estimatedBurned: 2400,
            customBurned: 2400,
            balanceGoal: 0,
            isLoss: true
        )
        precondition(shortDay.progress == 0.5 && shortDay.current.burned == 1200)
        print("Energy contour checks passed")
    }

}
