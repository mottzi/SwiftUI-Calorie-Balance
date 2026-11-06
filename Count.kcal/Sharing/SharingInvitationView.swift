import SwiftUI
import CloudKit

/// Scope choices followed by Apple's private recipient selection and delivery sheet.
struct SharingInvitationView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var today = true
    @State private var history = false
    @State private var streaks = false
    @State private var isCreating = false
    @State private var showsDisclosure = false
    @State private var nativeInvitation: SharingCloudInvitation?
    @State private var handoffCompleted = false
    @State private var handoffError: Error?
    @State private var invitationErrorMessage: String?

    let runtime: SharingRuntime

    private var scopes: Set<SharingScope> {
        Set((today ? [SharingScope.today] : []) + (history ? [.history] : []) + (streaks ? [.streaks] : []))
    }

    private var isLocked: Bool { isCreating || runtime.isWorking }

    /// Retains scope choices after errors and lets the system choose the recipient.
    var body: some View {
        Group {
            if runtime.hasDisplayName {
                invitation
            } else {
                SharingNameEditor(runtime: runtime, onSaved: {})
            }
        }
        .onAppear { runtime.clearError() }
        .onDisappear { runtime.clearInvitation() }
    }

    private var invitation: some View {
        NavigationStack {
            SharingCompactSheetBody {
                if let coordinator = runtime.coordinator {
                    SharingSentInvitationsView(runtime: runtime, coordinator: coordinator, nativeInvitation: $nativeInvitation)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Share with each other")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        Toggle("Today", isOn: $today)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                        Divider().padding(.leading, 16)
                        Toggle("Previous 6 Days", isOn: $history)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                        Divider().padding(.leading, 16)
                        Toggle("Streak", isOn: $streaks)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                    }
                    .padding(.vertical, 4)
                    .background(.background.secondary, in: .rect(cornerRadius: 24))
                    .disabled(isLocked || runtime.invitationCreated)
                    Group {
                        if scopes.isEmpty {
                            Text("Choose at least one option to continue.")
                        } else if streaks {
                            Text("The full streak can extend beyond Previous 6 Days.")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                }
                SharingDetailsButton(alignment: .center) { showsDisclosure = true }
                if isCreating { ProgressView("Preparing invitation…") }
                if runtime.isFixture, runtime.invitationCreated { Text("Sample invitation created") }
                if runtime.publisherNeedsConfirmation, let coordinator = runtime.coordinator {
                    SharingPublisherChoice(runtime: runtime, coordinator: coordinator)
                }
                if let error = invitationErrorMessage {
                    Text(error).foregroundStyle(.secondary)
                }
            } actions: {
                Button { sendInvitation() } label: {
                    Label("Share invitation…", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .modifier(SharingPrimaryActionAppearance())
                .disabled(isLocked || scopes.isEmpty || runtime.invitationCreated)
            }
            .softTopScrollEdge()
            .navigationTitle("Invite someone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26, *) {
                        Button(role: .close) { dismiss() }.disabled(isLocked)
                    } else {
                        Button("Done") { dismiss() }.disabled(isLocked)
                    }
                }
            }
            .sheet(isPresented: $showsDisclosure) { SharingDisclosureView() }
            .sheet(item: $nativeInvitation, onDismiss: {
                if handoffCompleted, handoffError == nil { dismiss() }
                Task {
                    await runtime.finishInvitation(error: handoffError)
                    invitationErrorMessage = runtime.actionError
                }
            }) { invitation in
                SharingNativeInvitationSheet(invitation: invitation) { completed, error in
                    handoffCompleted = completed
                    handoffError = error
                    nativeInvitation = nil
                }
            }
            .interactiveDismissDisabled(isLocked)
        }
    }

    private func sendInvitation() {
        guard !isLocked, !scopes.isEmpty, runtime.hasDisplayName else { return }
        isCreating = true
        invitationErrorMessage = nil
        Task {
            defer { isCreating = false }
            if runtime.invitation == nil, !runtime.invitationCreated {
                guard await runtime.invite(scopes: scopes) else {
                    invitationErrorMessage = runtime.actionError
                    return
                }
            }
            handoffCompleted = false
            handoffError = nil
            nativeInvitation = runtime.invitation
        }
    }

}

/// Native invitation delivery with private recipient and setup permissions fixed by the app.
struct SharingNativeInvitationSheet: UIViewControllerRepresentable {

    let invitation: SharingCloudInvitation
    let completion: (Bool, Error?) -> Void

    /// Retains the CloudKit provider and the native activity completion for this presentation.
    func makeCoordinator() -> Coordinator { Coordinator(invitation: invitation, completion: completion) }

    /// Opens invitation delivery directly instead of the existing-share people manager.
    func makeUIViewController(context: Context) -> UIActivityViewController {

        let configuration = UIActivityItemsConfiguration(itemProviders: [context.coordinator.provider])
        configuration.metadataProvider = { key in
            key == .title ? String(localized: "Invitation to share calorie cards") : nil
        }
        let controller = UIActivityViewController(activityItemsConfiguration: configuration)
        controller.completionWithItemsHandler = { [weak coordinator = context.coordinator] _, completed, _, error in
            Task { @MainActor in coordinator?.finish(completed: completed, error: error) }
        }
        return controller
    }

    /// Preserves the selected activity and preparation task during SwiftUI updates.
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }

    @MainActor
    /// Registers fresh preparation separately from saved-share recovery and reports completion once.
    final class Coordinator: NSObject {

        let provider = NSItemProvider()

        private let completion: (Bool, Error?) -> Void
        private var completed = false

        init(invitation: SharingCloudInvitation, completion: @escaping (Bool, Error?) -> Void) {

            self.completion = completion
            super.init()
            let options = CKAllowedSharingOptions(
                allowedParticipantPermissionOptions: .readWrite,
                allowedParticipantAccessOptions: .specifiedRecipientsOnly
            )
            if #available(iOS 26.0, *) {
                options.allowsParticipantsToInviteOthers = false
                options.allowsAccessRequests = false
            }
            provider.suggestedName = String(localized: "Invitation to share calorie cards")
            if let share = invitation.share {
                provider.registerCKShare(share, container: invitation.container, allowedSharingOptions: options)
            } else {
                provider.registerCKShare(container: invitation.container, allowedSharingOptions: options) {
                    try await invitation.prepareShare()
                }
            }
        }

        /// Reports one delivery result; activity completion does not imply calorie consent.
        func finish(completed: Bool, error: Error?) {
            guard !self.completed else { return }
            self.completed = true
            completion(completed, error)
        }

    }

}

/// Secondary explanation is available without repeating it in each decision sheet.
private struct SharingDetailsButton: View {

    var alignment: Alignment = .leading
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("How sharing works", systemImage: "info.circle")
                .frame(maxWidth: .infinity, minHeight: 44, alignment: alignment)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .buttonStyle(.borderless)
    }

}

/// Complete sharing explanation kept available before consent and in the profile.
struct SharingDisclosureView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form { SharingDisclosureText() }
            .softTopScrollEdge()
            .navigationTitle("How sharing works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26, *) {
                        Button(role: .close) { dismiss() }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

}

/// Card fields, storage, date windows, and access-removal limits.
struct SharingDisclosureText: View {

    @State private var showsSharedInformation = true

    var body: some View {
        Section {
            Label("Calorie cards", systemImage: "rectangle.on.rectangle")
        } footer: {
            Text("Raw Health samples, meals, weight, steps and hidden goal targets are not shared.")
        }
        Section {
            DisclosureGroup(isExpanded: $showsSharedInformation) {
                details {
                    Text("You both share daily calorie cards with burned and eaten energy, active and resting calories, balance, and any visible goal result.")
                    Text("Today can include a midnight estimate. Each card keeps its sender's units and colors.")
                    Text("Streak is optional. It shares the full consecutive completed-day count, which can extend beyond the six shared days. Hidden goal status also hides the streak.")
                }
            } label: {
                Label("Shared information", systemImage: "rectangle.stack")
            }
        }
        Section {
            DisclosureGroup {
                details {
                    Text("Cards follow the sender's calendar days. Previous 6 Days covers the six completed days before today, including days before you connected.")
                    Text("Cards update when Count.kcal receives new data. Updates may be delayed.")
                }
            } label: {
                Label("Dates and updates", systemImage: "calendar")
            }
        }
        Section {
            DisclosureGroup {
                details {
                    Text("Either person can reduce or stop sharing for both of you. Adding days or resuming requires the other person's agreement.")
                    Text("Reductions take effect on this iPhone when saved. Removing iCloud access may take longer, and older cloud copies can remain accessible until the sender's iPhone removes them.")
                    Text("Downloaded copies and screenshots cannot be erased.")
                }
            } label: {
                Label("Changing sharing", systemImage: "slider.horizontal.3")
            }
        }
        Section {
            DisclosureGroup {
                details {
                    Text("Choose how to send, then select one person. Sharing starts after they accept. The invitation expires in 7 days.")
                }
            } label: {
                Label("Invitations", systemImage: "envelope")
            }
        }
        Section {
            DisclosureGroup {
                details {
                    Text("Cards are shared privately through iCloud with the person you connected with. End-to-end protection depends on iCloud settings and sharing conditions.")
                }
            } label: {
                Label("Privacy", systemImage: "hand.raised")
            }
        }
        .tint(.primary)
    }

    private func details<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
    }

}

/// A specific proposal with separate acceptance and decline actions.
struct SharingRequestConsentView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var showsDisclosure = false
    @State private var showsNameSetup = false
    @State private var isSubmitting = false
    @State private var reviewedConnection: SharingConnection?

    let runtime: SharingRuntime
    let coordinator: SharingCoordinator
    let connectionID: UUID

    init(runtime: SharingRuntime, coordinator: SharingCoordinator, connectionID: UUID) {
        self.runtime = runtime
        self.coordinator = coordinator
        self.connectionID = connectionID
        _reviewedConnection = State(initialValue: coordinator.connections.first { $0.id == connectionID })
    }

    var body: some View {
        NavigationStack {
            SharingCompactSheetBody {
                if let connection = displayedConnection, let proposal = connection.proposal {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(connection.peer(of: coordinator.identity?.id ?? "")?.displayName ?? "")
                            .font(.title3.bold())
                            .padding(.horizontal, 16)
                        Text("Share with each other")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                        VStack(spacing: 0) {
                            if proposal.scopes.contains(.today) {
                                scopeRow("Today", alreadyShared: connection.scopes.contains(.today))
                            }
                            if proposal.scopes.contains(.today) && proposal.scopes.contains(.history) {
                                Divider().padding(.leading, 16)
                            }
                            if proposal.scopes.contains(.history) {
                                scopeRow("Previous 6 Days", alreadyShared: connection.scopes.contains(.history))
                            }
                            if proposal.scopes.contains(.streaks) {
                                if !proposal.scopes.intersection([.today, .history]).isEmpty { Divider().padding(.leading, 16) }
                                scopeRow("Streak", alreadyShared: connection.scopes.contains(.streaks))
                            }
                        }
                        .padding(.vertical, 4)
                        .background(.background.secondary, in: .rect(cornerRadius: 24))
                        if proposal.scopes.contains(.streaks) {
                            Text("The full streak can extend beyond Previous 6 Days.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                        }
                        if connection.scopes.isEmpty, !connection.isInitialRequest {
                            Text("Sharing stays paused until you accept.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                        }
                    }
                    SharingDetailsButton { showsDisclosure = true }
                    if runtime.publisherNeedsConfirmation {
                        SharingPublisherChoice(runtime: runtime, coordinator: coordinator)
                    }
                    if let error = runtime.actionError ?? coordinator.lastError {
                        Text(error).foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView("This request is no longer available", systemImage: "person.crop.circle.badge.clock")
                }
            } actions: {
                if displayedConnection?.proposal != nil {
                    Button(action: accept) {
                        HStack {
                            if isSubmitting { ProgressView() }
                            Text("Accept")
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .modifier(SharingPrimaryActionAppearance())
                    .disabled(runtime.isWorking || isSubmitting)
                    Button(role: .destructive, action: decline) {
                        Text("Decline").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .disabled(runtime.isWorking || isSubmitting)
                }
            }
            .softTopScrollEdge()
            .navigationTitle(reviewedConnection?.requestTitle ?? "Sharing request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26, *) {
                        Button(role: .close) { dismiss() }.disabled(runtime.isWorking || isSubmitting)
                    } else {
                        Button("Done") { dismiss() }.disabled(runtime.isWorking || isSubmitting)
                    }
                }
            }
            .sheet(isPresented: $showsDisclosure) { SharingDisclosureView() }
            .sheet(isPresented: $showsNameSetup) {
                SharingNameEditor(runtime: runtime) {
                    showsNameSetup = false
                    accept()
                }
            }
            .interactiveDismissDisabled(runtime.isWorking || isSubmitting)
        }
        .onAppear { runtime.clearError() }
    }

    private var connection: SharingConnection? {
        coordinator.connections.first { $0.id == connectionID }
    }

    private var displayedConnection: SharingConnection? {
        if isSubmitting { return reviewedConnection }
        guard let connection, connection.proposal?.id == reviewedConnection?.proposal?.id else { return nil }
        return connection
    }

    private func scopeRow(_ title: LocalizedStringResource, alreadyShared: Bool) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            if alreadyShared {
                Text("Already shared")
                    .font(.subheadline)
                    .foregroundStyle(.green.secondary)
            } else {
                Text("New")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }

    private func accept() {
        guard !runtime.isWorking, !isSubmitting, let proposal = displayedConnection?.proposal else { return }
        guard runtime.hasDisplayName else {
            showsNameSetup = true
            return
        }
        reviewedConnection = connection
        isSubmitting = true
        Task {
            let accepted = await runtime.perform(on: coordinator) {
                try await coordinator.preparePublisher()
                try await coordinator.accept(connectionID: connectionID, proposalID: proposal.id)
            }
            if accepted { dismiss() } else { isSubmitting = false }
        }
    }

    private func decline() {
        guard !runtime.isWorking, !isSubmitting, let proposal = displayedConnection?.proposal else { return }
        reviewedConnection = connection
        isSubmitting = true
        Task {
            let declined = await runtime.perform(on: coordinator) {
                try await coordinator.decline(connectionID: connectionID, proposalID: proposal.id)
            }
            if declined { dismiss() } else { isSubmitting = false }
        }
    }

}

/// Content and actions share one scroll container, including while the keyboard is visible.
private struct SharingCompactSheetBody<Content: View, Actions: View>: View {

    @State private var contentHeight: CGFloat = 180
    @State private var navigationHeight: CGFloat = 0

    let content: Content
    let actions: Actions

    init(@ViewBuilder content: () -> Content, @ViewBuilder actions: () -> Actions) {
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                content
                VStack(spacing: 8) { actions }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .onGeometryChange(for: CGFloat.self) { geometry in
                ceil(geometry.size.height)
            } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.safeAreaInsets.top
        } action: { navigationHeight = $0 }
        .presentationDetents([.height(contentHeight + navigationHeight)])
        .presentationDragIndicator(.visible)
    }

}

private struct SharingPrimaryActionAppearance: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}
