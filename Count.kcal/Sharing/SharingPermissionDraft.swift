import Foundation

/// An editable request keeps accepted permission separate from the pending selection.
struct SharingPermissionDraft {
    let acceptedScopes: Set<SharingScope>
    let proposal: SharingProposal?
    let baselineScopes: Set<SharingScope>
    var today: Bool
    var history: Bool
    var streaks: Bool

    init(connection: SharingConnection, accountID: String?) {
        acceptedScopes = connection.scopes
        proposal = connection.proposal
        baselineScopes = connection.proposal.flatMap { $0.proposerID == accountID ? $0.scopes : nil } ?? connection.scopes
        today = baselineScopes.contains(.today)
        history = baselineScopes.contains(.history)
        streaks = baselineScopes.contains(.streaks)
    }

    var scopes: Set<SharingScope> {
        Set((today ? [SharingScope.today] : []) + (history ? [.history] : []) + (streaks ? [.streaks] : []))
    }

    var isEdited: Bool { scopes != baselineScopes }
    var additions: Set<SharingScope> { scopes.subtracting(acceptedScopes) }
    var reductions: Set<SharingScope> { acceptedScopes.subtracting(scopes) }

    func matches(_ connection: SharingConnection) -> Bool {
        connection.scopes == acceptedScopes && connection.proposal == proposal
    }
}
