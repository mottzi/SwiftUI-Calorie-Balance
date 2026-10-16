#if (DEBUG && targetEnvironment(simulator)) || WEIGHT_CHART_TESTS
import Foundation

/// Repeatable chart inputs shared by simulator visual checks and semantic tests.
struct WeightChartScenario: Identifiable {
    let id: String
    let end: Date
    let dailyAverages: [WeightChartData]

    init(_ name: String, end: Date, value: (Int, Int) -> Double?) {
        id = name
        self.end = end
        let start = end.subtractDays(30).lastMonday
        let count = Calendar.current.dateComponents([.day], from: start, to: end).day! + 1
        dailyAverages = (0..<count).map { index in
            WeightChartData(
                date: start.addDays(index),
                weightAvg: value(index, count).map(WeightChartData.roundedWeight)
            )
        }
    }

    static let cases: [Self] = {
        let calendar = Calendar.current
        let friday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 16))!
        func trend(_ start: Double, _ end: Double, _ index: Int, _ count: Int) -> Double {
            start + (end - start) * Double(index) / Double(count - 1)
        }
        var result: [Self] = [
            .init("01 steady loss", end: friday) { i, n in trend(82.4, 79.6, i, n) },
            .init("02 steady gain", end: friday) { i, n in trend(77.6, 80.4, i, n) },
            .init("03 flat integer", end: friday) { _, _ in 80 },
            .init("04 flat fraction", end: friday) { _, _ in 80.5 },
            .init("05 near upper bound", end: friday) { i, _ in 79.9 + Double(i % 3) * 0.04 },
            .init("06 near lower bound", end: friday) { i, _ in 80.01 + Double(i % 3) * 0.04 },
            .init("07 sharp peaks", end: friday) { i, _ in [80.2, 80.85, 80.99, 80.9, 80.3, 80.1, 80.0][i % 7] },
            .init("08 sharp troughs", end: friday) { i, _ in [79.8, 79.15, 79.01, 79.1, 79.7, 79.9, 80.0][i % 7] },
            .init("09 rapid loss", end: friday) { i, n in trend(110, 75, i, n) },
            .init("10 rapid gain", end: friday) { i, n in trend(75, 110, i, n) },
            .init("11 high outlier", end: friday) { i, n in i == n - 4 ? 106.9 : 80.2 },
            .init("12 low outlier", end: friday) { i, n in i == n - 4 ? 61.1 : 80.2 },
            .init("13 sparse readings", end: friday) { i, n in i % 5 == 0 || i == n - 1 ? trend(82, 79.6, i, n) : nil },
            .init("14 single latest reading", end: friday) { i, n in i == n - 1 ? 79.6 : nil },
            .init("15 single older reading", end: friday) { i, _ in i == 0 ? 79.6 : nil },
            .init("16 no readings", end: friday) { _, _ in nil },
            .init("17 stale latest reading", end: friday) { i, n in i < n - 9 ? trend(82, 79.6, i, n) : nil },
            .init("18 long middle gap", end: friday) { i, n in (8..<25).contains(i) ? nil : trend(82, 79.6, i, n) },
            .init("19 three digit pounds", end: friday) { i, n in trend(305.6, 301.2, i, n) },
            .init("20 lighter weight", end: friday) { i, n in trend(48.6, 49.4, i, n) },
            .init("21 three digit kilograms", end: friday) { i, n in trend(150.6, 148.2, i, n) },
            .init("22 alternating extremes", end: friday) { i, _ in i.isMultiple(of: 2) ? 79.01 : 80.99 },
            .init("23 integer crossing", end: friday) { i, n in trend(79.9, 80.1, i, n) },
            .init("24 isolated upper latest", end: friday) { i, n in i == n - 1 ? 80.99 : 79.2 },
            .init("25 isolated lower latest", end: friday) { i, n in i == n - 1 ? 79.01 : 80.8 }
        ]
        for weekday in 0..<7 {
            let end = friday.subtractDays(4).addDays(weekday)
            result.append(.init("\(26 + weekday) weekday ending \(weekday + 1)", end: end) { i, n in
                trend(79.4, 80.6, i, n)
            })
        }
        for (name, components) in [
            ("33 year boundary", DateComponents(year: 2027, month: 1, day: 3)),
            ("34 leap day", DateComponents(year: 2028, month: 2, day: 29)),
            ("35 spring clock change", DateComponents(year: 2026, month: 3, day: 29)),
            ("36 autumn clock change", DateComponents(year: 2026, month: 10, day: 25))
        ] {
            result.append(.init(name, end: calendar.date(from: components)!) { i, n in trend(82.4, 79.6, i, n) })
        }
        return result
    }()
}
#endif
