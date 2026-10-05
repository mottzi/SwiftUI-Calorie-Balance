import Foundation

/// Daily energy history and a separate end-of-day expenditure estimate.
struct EnergyContour: Equatable {

    let points: [Point]
    let progress: Double
    let estimatedBurned: Double
    let isBurnEstimated: Bool
    let budget: ComplicationCalorieBudget

    init(
        start: Date,
        end: Date,
        now: Date,
        burned: [Date: Double],
        consumed: [Date: Double],
        estimatedBurned: Double,
        customBurned: Double? = nil,
        balanceGoal: Int,
        isLoss: Bool
    ) {

        let duration = max(end.timeIntervalSince(start), 1)
        progress = min(max(now.timeIntervalSince(start) / duration, 0), 1)
        isBurnEstimated = customBurned != nil
        var history = [Point(time: 0, burned: 0, consumed: 0)]
        var burnedSum = 0.0
        var consumedSum = 0.0
        let dates = Set(burned.keys).union(consumed.keys).sorted().filter { $0 >= start && $0 < min(now, end) }
        for date in dates {
            burnedSum += Self.valid(burned[date, default: 0])
            consumedSum += Self.valid(consumed[date, default: 0])
            let time = min(date.addingTimeInterval(900).timeIntervalSince(start) / duration, progress)
            history.append(Point(
                time: time,
                burned: customBurned.map { Self.valid($0) * time } ?? burnedSum,
                consumed: consumedSum
            ))
        }
        if let customBurned { burnedSum = Self.valid(customBurned) * progress }
        if history.last?.time != progress || history.last?.burned != burnedSum {
            history.append(Point(time: progress, burned: burnedSum, consumed: consumedSum))
        }
        points = history
        self.estimatedBurned = max(Self.valid(estimatedBurned), burnedSum)
        budget = ComplicationCalorieBudget(
            burned: Int(self.estimatedBurned.rounded()),
            consumed: Int(consumedSum.rounded()),
            balanceGoal: balanceGoal,
            isLoss: isLoss
        )
    }

    var current: Point { points.last! }

    var scale: Double { max(estimatedBurned, current.consumed, 1) * 1.08 }

    var hasData: Bool { estimatedBurned > 0 || current.consumed > 0 }

}

extension EnergyContour {

    private static func valid(_ value: Double) -> Double { value.isFinite ? max(value, 0) : 0 }

}

extension EnergyContour {

    /// Cumulative totals at the end of a measured interval.
    struct Point: Equatable {
        let time: Double
        let burned: Double
        let consumed: Double
    }

}
