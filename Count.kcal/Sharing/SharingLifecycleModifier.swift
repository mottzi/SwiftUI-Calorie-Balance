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
            .onChange(of: HealthRepository.shared.revision) { runtime.schedulePublication(settings: settings) }
            .onChange(of: publicationSettings) { runtime.schedulePublication(settings: settings) }
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

    /// Compare published inputs, not every notification from the settings object.
    private var publicationSettings: PublicationSettings {
        PublicationSettings(
            policy: HealthSnapshotPolicy(settings: settings),
            burned: settings.burnedColor,
            consumed: settings.consumedColor,
            background: settings.appBackground,
            labelBackground: settings.showCalorieLabelBackgrounds ? settings.calorieLabelBackground : nil
        )
    }

    private struct PublicationSettings: Equatable {
        let policy: HealthSnapshotPolicy
        let burned: Color
        let consumed: Color
        let background: Settings.AppBackgrounds
        let labelBackground: Settings.AppBackgrounds?
    }
}

/// Shows imported invitation progress and opens consent after the proposal arrives.
struct SharingReceivedInvitationView: View {

    @Environment(\.dismiss) private var dismiss

    let runtime: SharingRuntime
    @State private var requestConnectionID: UUID?

    private var incomingConnectionID: UUID? {
        guard case .request(let id) = runtime.receivedInvitationState else { return nil }
        return id
    }

    var body: some View {
        Group {
            if let coordinator = runtime.coordinator, let requestConnectionID = requestConnectionID ?? incomingConnectionID {
                SharingRequestConsentView(runtime: runtime, coordinator: coordinator, connectionID: requestConnectionID)
            } else if let coordinator = runtime.coordinator, case .connected(let id) = runtime.receivedInvitationState {
                NavigationStack {
                    SharingPersonDetail(runtime: runtime, coordinator: coordinator, connectionID: id)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { dismiss() }
                            }
                        }
                }
            } else {
                NavigationStack {
                    Group {
                        if runtime.receivedInvitationState == .pending {
                            ProgressView("Finishing invitation…")
                        } else {
                            ContentUnavailableView("This request is no longer available", systemImage: "person.crop.circle.badge.clock")
                        }
                    }
                        .navigationTitle("Sharing request")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { dismiss() }
                            }
                        }
                }
            }
        }
        .onChange(of: incomingConnectionID, initial: true) {
            if requestConnectionID == nil { requestConnectionID = incomingConnectionID }
        }
    }

}
