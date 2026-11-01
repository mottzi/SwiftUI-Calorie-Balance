import Foundation
import Testing
@testable import Count_kcal

@Suite(.serialized) @MainActor
/// Durable request-alert claim behavior across refreshes, accounts, and writers.
struct SharingRequestAlertTests {

    /// Fixed claim time for request-alert scenarios.
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Creates a request with the selected recipient and identifier.
    private func proposal(recipient: String = "bob", id: UUID = UUID()) -> SharingProposal {
        SharingProposal(
            id: id,
            proposerID: "alice",
            recipientID: recipient,
            baseRevision: 0,
            scopes: [.today],
            createdAt: now,
            expiresAt: now.addingTimeInterval(604_800)
        )
    }

    @Test
    /// Persists a claim across refresh and database reopen.
    func refreshesAndDatabaseReopensClaimOnlyOnce() throws {

        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let request = proposal()
        let first = try SharingStore(path: path)
        #expect(try first.claimRequestAlert(request, verifiedAccountID: "bob", now: now))
        #expect(try !first.claimRequestAlert(request, verifiedAccountID: "bob", now: now))
        let reopened = try SharingStore(path: path)
        #expect(try !reopened.claimRequestAlert(request, verifiedAccountID: "bob", now: now.addingTimeInterval(1)))
    }

    @Test
    /// Keeps an existing claim when account state is cleared or switched.
    func accountSwitchesAndCachePurgesDoNotRepeatAnAlert() throws {

        let store = try SharingStore()
        let request = proposal()
        #expect(try store.claimRequestAlert(request, verifiedAccountID: "bob", now: now))
        try store.clear(accountID: "bob")
        try store.clearOtherAccounts(keeping: "charlie")
        #expect(try !store.claimRequestAlert(request, verifiedAccountID: "bob", now: now))
        #expect(
            try store.claimRequestAlert(
                proposal(recipient: "charlie", id: request.id),
                verifiedAccountID: "charlie",
                now: now
            )
        )
    }

    @Test
    /// Leaves a request unclaimed for a mismatched or unverified identity.
    func wrongRecipientAndUnverifiedIdentityCannotConsumeAClaim() throws {

        let store = try SharingStore()
        let request = proposal()
        #expect(try !store.claimRequestAlert(request, verifiedAccountID: "alice", now: now))
        #expect(try !store.claimRequestAlert(request, verifiedAccountID: "", now: now))
        #expect(try store.claimRequestAlert(request, verifiedAccountID: "bob", now: now))
    }

    @Test
    /// Rejects expired, future-dated, and overlong requests before claiming them.
    func expiredFutureAndOverlongRequestsCannotAlert() throws {

        let store = try SharingStore()
        let request = proposal()
        #expect(try !store.claimRequestAlert(request, verifiedAccountID: "bob", now: request.expiresAt))
        #expect(try !store.claimRequestAlert(request, verifiedAccountID: "bob", now: now.addingTimeInterval(-1)))
        var overlong = request
        overlong.expiresAt = request.expiresAt.addingTimeInterval(1)
        #expect(try !store.claimRequestAlert(overlong, verifiedAccountID: "bob", now: now))
        #expect(try store.claimRequestAlert(request, verifiedAccountID: "bob", now: now))
        try store.expireRequestAlerts(now: request.expiresAt)
        #expect(
            try !store.claimRequestAlert(
                request,
                verifiedAccountID: "bob",
                now: request.expiresAt.addingTimeInterval(1)
            )
        )
    }

    @Test
    /// Allows only one independent store to claim the same request.
    func independentWritersCannotClaimTheSameRequest() throws {

        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let first = try SharingStore(path: path), second = try SharingStore(path: path)
        let request = proposal()
        #expect(try first.claimRequestAlert(request, verifiedAccountID: "bob", now: now))
        #expect(try !second.claimRequestAlert(request, verifiedAccountID: "bob", now: now))
        #expect(try second.claimRequestAlert(proposal(), verifiedAccountID: "bob", now: now))
    }

}
