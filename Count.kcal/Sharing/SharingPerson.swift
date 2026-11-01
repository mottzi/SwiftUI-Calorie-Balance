import Foundation

/// A visible person and the service that owns their cards and sharing actions.
struct SharingPerson: Identifiable {
    let connection: SharingConnection
    let coordinator: SharingCoordinator
    var isSample = false

    var id: UUID { connection.id }
    @MainActor var name: String { connection.peer(of: coordinator.identity?.id ?? "")?.displayName ?? "" }
}
