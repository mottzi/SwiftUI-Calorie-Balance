import Foundation
import Observation

@MainActor
@Observable
/// Completed-day energy and weight history for the progress summary.
final class ProgressHistory {

    private(set) var energy: [ProgressDay] = []
    private(set) var weights: [Date: Double] = [:]
    private(set) var today = Calendar.current.startOfDay(for: Date.now)
    private(set) var isLoading = false
    private(set) var energyFailed = false
    private(set) var weightFailed = false

    @ObservationIgnored private var requestID = 0

    func refresh(repository: HealthRepository? = nil, settings: Settings? = nil) async {

        let repository = repository ?? .shared
        let settings = settings ?? .shared
        requestID += 1
        let request = requestID
        let revision = repository.revision
        let day = Calendar.current.startOfDay(for: Date.now)
        let policy = ProgressPolicy(settings: settings)
        isLoading = true
        energyFailed = false
        weightFailed = false
        defer { if request == requestID { isLoading = false } }

        async let energyResult = Result { try await repository.fetchProgressEnergy(before: day, policy: policy) }
        async let weightResult = Result { try await repository.fetchProgressWeights(before: day, policy: policy) }
        let results = await (energyResult, weightResult)
        guard !Task.isCancelled, request == requestID, revision == repository.revision,
              policy == ProgressPolicy(settings: settings) else { return }
        today = day
        switch results.0 {
            case .success(let values): energy = values

            case .failure:
                energy = []
                energyFailed = true
        }
        switch results.1 {
            case .success(let values): weights = values

            case .failure:
                weights = [:]
                weightFailed = true
        }
    }

    func summary(for period: ProgressPeriod, choices: [String: DayChoice]) -> ProgressSummary {
        ProgressSummary(period: period, today: today, energy: energy, weights: weights, choices: choices)
    }

}

/// Fixed settings used throughout one asynchronous progress refresh.
struct ProgressPolicy: Equatable, Sendable {
    let customEnergy: Bool
    let customActive: Int
    let customResting: Int
    let energyUnit: String
    let weightUnit: String

    @MainActor
    init(settings: Settings) {
        customEnergy = settings.usesCustomEnergy
        customActive = settings.customCalActive
        customResting = settings.customCalPassive
        energyUnit = settings.energyUnit.rawValue
        weightUnit = settings.weightUnit.rawValue
    }
}

extension Result where Failure == Error {

    fileprivate init(catching operation: () async throws -> Success) async {
        do { self = .success(try await operation()) }
        catch { self = .failure(error) }
    }

}
