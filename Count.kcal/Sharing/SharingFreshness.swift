import Foundation

/// Foreground reconciliation policy, independent of view lifetime and wall-clock timers.
struct SharingFreshness {
    static let visibleInterval: TimeInterval = 60
    private(set) var lastSuccess: Date?
    private(set) var retryNotBefore: Date?
    private(set) var failures = 0

    func shouldRefresh(at now: Date, changed: Bool = false) -> Bool {
        if let retryNotBefore, now < retryNotBefore { return false }
        return changed || lastSuccess.map { now.timeIntervalSince($0) >= Self.visibleInterval } ?? true
    }

    func nextRefreshDelay(at now: Date) -> TimeInterval {
        if let retryNotBefore { return max(1, retryNotBefore.timeIntervalSince(now)) }
        return max(1, (lastSuccess?.addingTimeInterval(Self.visibleInterval) ?? now).timeIntervalSince(now))
    }

    mutating func succeeded(at now: Date) {
        lastSuccess = now
        retryNotBefore = nil
        failures = 0
    }

    mutating func failed(at now: Date, serverDelay: TimeInterval? = nil) {
        failures = min(failures + 1, 8)
        let backoff = min(300, 5 * pow(2, Double(failures - 1)))
        retryNotBefore = now.addingTimeInterval(max(backoff, serverDelay ?? 0))
    }
}
