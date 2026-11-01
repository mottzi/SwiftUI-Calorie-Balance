import SwiftUI
import CloudKit
import SQLiteData

/// Dashboard lifecycle hooks for sharing refresh side effects.
struct SharingLifecycleModifier: ViewModifier {

    /// Current app activity state used to gate foreground refresh.
    @Environment(\.scenePhase) private var scenePhase

    /// Settings used to schedule publication after value changes.
    @EnvironmentObject private var settings: Settings

    /// Whether the user has opened sharing before.
    @AppStorage("sharing.used") private var hasUsedSharing = false

    @FetchAll private var dayChoices: [StoredDayChoice]

    /// Runtime that handles sharing refresh, publication, and invitation work.
    let runtime: SharingRuntime

    /// Routes dashboard lifecycle, settings, calendar, account, and invitation events to sharing.
    func body(content: Content) -> some View {
        content
            .task(id: scenePhase == .active && hasUsedSharing) {
                guard scenePhase == .active, hasUsedSharing else { return }
                await runtime.refreshIfUsed(settings: settings)
                await runtime.expireWhileActive()
            }
            .onChange(of: dayChoices) { runtime.schedulePublication(settings: settings) }
            .onChange(of: HealthDataMode.shared.revision) { runtime.schedulePublication(settings: settings) }
            .onReceive(settings.objectWillChange) { _ in runtime.schedulePublication(settings: settings) }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
            ) { _ in runtime.schedulePublication(settings: settings) }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            ) { _ in runtime.schedulePublication(settings: settings) }
            .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
                Task { await runtime.accountDidChange(settings: settings) }
            }
            .onOpenURL { url in Task { await runtime.importInvitation(url: url) } }
            .sheet(isPresented: Binding(
                get: { runtime.receivedInvitationID != nil },
                set: { if !$0 { runtime.receivedInvitationID = nil } }
            )) {
                SharingReceivedInvitationView(runtime: runtime)
            }
    }

}

/// Shows imported invitation progress and opens consent after the proposal arrives.
private struct SharingReceivedInvitationView: View {

    @Environment(\.dismiss) private var dismiss

    let runtime: SharingRuntime

    var body: some View {
        if let coordinator = runtime.coordinator,
           let connection = coordinator.connections.first(where: { $0.id == runtime.receivedInvitationID }),
           connection.proposal?.recipientID == coordinator.identity?.id {
            SharingRequestConsentView(runtime: runtime, coordinator: coordinator, connectionID: connection.id)
        } else {
            NavigationStack {
                SharingOverviewView(runtime: runtime)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
        }
    }

}
