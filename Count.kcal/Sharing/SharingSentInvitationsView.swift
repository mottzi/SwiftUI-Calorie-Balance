import SwiftUI

/// Saved outgoing invitations are recovered in the invitation flow, away from shared cards.
struct SharingSentInvitationsView: View {
    let runtime: SharingRuntime
    let coordinator: SharingCoordinator
    @Binding var nativeInvitation: SharingCloudInvitation?
    @State private var failedInvitationID: UUID?
    @State private var errorMessage: String?

    private var drafts: [SharingPendingInvitation] {
        runtime.pendingInvitations.filter {
            if case .awaitingRecipient = $0.stage { return true }
            return false
        }
    }

    private var requests: [SharingConnection] {
        coordinator.connections.filter { $0.isInitialRequest && $0.proposal?.proposerID == coordinator.identity?.id }
    }

    var body: some View {
        ForEach(drafts) { invitation in
            VStack(alignment: .leading, spacing: 8) {
                if case .awaitingRecipient(let name, let scopes, _, _) = invitation.stage {
                    Text(name).font(.headline)
                    Text(scopes.sharingDescription).foregroundStyle(.secondary)
                    Button("Continue invitation", systemImage: "square.and.arrow.up") {
                        Task {
                            nativeInvitation = await runtime.resumeInvitation(id: invitation.id)
                            showError(for: invitation.id, failed: nativeInvitation == nil)
                        }
                    }
                    .frame(minHeight: 44)
                    Button("Cancel invitation", role: .destructive) {
                        Task {
                            let cancelled = await runtime.cancelPendingInvitation(id: invitation.id)
                            showError(for: invitation.id, failed: !cancelled)
                        }
                    }
                    .frame(minHeight: 44)
                    if failedInvitationID == invitation.id, let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.borderless)
            .disabled(runtime.isWorking)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: 24))
        }
        ForEach(requests) { connection in
            VStack(alignment: .leading, spacing: 8) {
                Text(connection.peer(of: coordinator.identity?.id ?? "")?.displayName ?? "")
                    .font(.headline)
                if let proposal = connection.proposal {
                    Text(proposal.scopes.sharingDescription).foregroundStyle(.secondary)
                    Text("Waiting for acceptance").font(.subheadline).foregroundStyle(.secondary)
                    Button("Cancel request", role: .destructive) {
                        Task {
                            let cancelled = await runtime.perform(on: coordinator) {
                                try await coordinator.cancel(connectionID: connection.id, proposalID: proposal.id)
                            }
                            showError(for: connection.id, failed: !cancelled)
                            if cancelled { runtime.clearInvitation() }
                        }
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .disabled(runtime.isWorking)
                }
                if failedInvitationID == connection.id, let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: 24))
        }
    }

    private func showError(for id: UUID, failed: Bool) {
        failedInvitationID = failed ? id : nil
        errorMessage = failed ? runtime.actionError : nil
    }
}
