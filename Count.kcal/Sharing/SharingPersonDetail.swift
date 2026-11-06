import SwiftUI

/// One person's sender-rendered cards and contextual sharing controls.
struct SharingPersonDetail: View {

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var scheme

    @EnvironmentObject private var settings: Settings
    @Environment(\.dismiss) private var dismiss

    @State private var mode = GraphMode.now
    @State private var showsPermissions = false
    @State private var showsRequest = false
    @State private var confirmsRemoval = false
    @State private var confirmsPause = false

    let runtime: SharingRuntime
    let coordinator: SharingCoordinator
    let connectionID: UUID

    private var connection: SharingConnection? { coordinator.connections.first { $0.id == connectionID } }

    private var peerName: String { connection?.peer(of: coordinator.identity?.id ?? "")?.displayName ?? "" }

    private var snapshots: [SharedSnapshotEnvelope] {
        let today = coordinator.snapshots(connectionID: connectionID, scope: .today)
        let history = coordinator.snapshots(connectionID: connectionID, scope: .history)
        return (today + history).sorted { $0.snapshot.dayStart > $1.snapshot.dayStart }
    }

    /// Shows permitted daily cards newest first, with requests and access warnings above them.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let connection {
                    if coordinator.pendingRevocations.contains(where: { $0.connectionID == connectionID }) {
                        SharingPendingRemovalView(runtime: runtime, coordinator: coordinator, connectionID: connectionID)
                    }
                    if connection.scopes.isSuperset(of: [.today, .history]), !snapshots.isEmpty {
                        SharedWeekBalanceChart(snapshots: snapshots.map(\.snapshot))
                            .padding(.horizontal, 4)
                    }
                    if snapshots.isEmpty, let proposal = connection.proposal,
                       proposal.recipientID == coordinator.identity?.id {
                        ContentUnavailableView {
                            Label(connection.requestTitle, systemImage: "person.crop.circle.badge.clock")
                        } actions: {
                            Button("Review request") { showsRequest = true }
                                .buttonStyle(.borderedProminent)
                        }
                    } else if snapshots.isEmpty {
                        ContentUnavailableView {
                            Label(connection.sharingStatus(coordinator: coordinator), systemImage: "person.crop.circle.badge.clock")
                        } description: {
                            Text(waitingGuidance(connection))
                        } actions: {
                            if connection.scopes.isEmpty && connection.proposal == nil {
                                Button("Request to resume") { showsPermissions = true }
                                    .buttonStyle(.bordered)
                                    .controlSize(.large)
                            }
                        }
                    } else {
                        ForEach(snapshots) { envelope in
                            SharingCardSection(
                                snapshot: envelope.snapshot,
                                isToday: envelope.scope == .today,
                                mode: envelope.scope == .today ? $mode : .constant(.now)
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
        .task(id: scenePhase == .active) {
            guard scenePhase == .active else { return }
            await runtime.observeSharingScreen(connectionID: connectionID)
        }
        .softTopScrollEdge()
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if #available(iOS 26, *) {
                leadingToolbarTitle.sharedBackgroundVisibility(.hidden)
                trailingToolbarItems.sharedBackgroundVisibility(.visible)
            } else {
                leadingToolbarTitle
                trailingToolbarItems
            }
        }
        .sheet(isPresented: $showsPermissions) {
            if let connection { SharingPermissionsView(runtime: runtime, coordinator: coordinator, connection: connection) }
        }
        .sheet(isPresented: $showsRequest) {
            SharingRequestConsentView(runtime: runtime, coordinator: coordinator, connectionID: connectionID)
        }
        .confirmationDialog("Remove \(peerName)?", isPresented: $confirmsRemoval, titleVisibility: .visible) {
            Button("Remove person", role: .destructive) {
                Task {
                    if await runtime.perform(on: coordinator, { try await coordinator.remove(connectionID: connectionID) }) { dismiss() }
                }
            }
        } message: {
            Text("Sharing ends for both of you. Reconnecting needs a new invitation. Removing iCloud access may take longer. Saved copies cannot be erased.")
        }
        .confirmationDialog("Pause sharing with \(peerName)?", isPresented: $confirmsPause, titleVisibility: .visible) {
            Button("Pause sharing") {
                Task { await runtime.perform(on: coordinator) { try await coordinator.changeScopes(connectionID: connectionID, to: []) } }
            }
        } message: {
            Text("Sharing pauses for both of you. Resuming needs the other person's agreement. Removing iCloud access may take longer. Saved copies cannot be erased.")
        }
        .onChange(of: snapshots.first(where: { $0.scope == .today })?.snapshot.senderLocalDate) {
            mode = .now
        }
        .onChange(of: connection == nil) { if connection == nil { dismiss() } }
        .modifier(StreakAnimationScope())
    }

}

extension SharingPersonDetail {

    private var leadingToolbarTitle: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            VStack(alignment: .leading, spacing: 1) {
                Text(peerName)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                if let updatedAt {
                    Text(updatedAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(isMissingToday ? Color.red : Color.secondary)
                        .accessibilityLabel(Text("Last shared \(Text(updatedAt, format: .relative(presentation: .named)))"))
                        .accessibilityValue(isMissingToday ? Text("No update yet today") : Text(""))
                }
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityElement(children: .combine)
        }
    }

    private var trailingToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let streak = coordinator.streak(connectionID: connectionID) {
                SharingStreakBadge(streak: streak)
            }
            Menu {
                Button {
                    showsPermissions = true
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                if connection?.proposal?.recipientID == coordinator.identity?.id {
                    Button("Review request", systemImage: "envelope") { showsRequest = true }
                }
                if connection?.scopes.isEmpty == false {
                    Button("Pause", systemImage: "pause.circle") { confirmsPause = true }
                }
                Button("Remove", systemImage: "person.crop.circle.badge.minus", role: .destructive) {
                    confirmsRemoval = true
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(Color("TextColor"))
                    .fontWeight(.medium)
            }
            .accessibilityLabel("Settings")
            .disabled(connection == nil || runtime.isWorking)
        }
    }

    private var pageBackground: Color {
        let presentation = snapshots + coordinator.snapshots(connectionID: connectionID, scope: .goals)
        guard let latest = presentation.max(by: { $0.snapshot.capturedAt < $1.snapshot.capturedAt })?.snapshot,
              let background = latest.appearance.pageBackground else { return settings.AppBackground }
        return latest.color(background, scheme: scheme)
    }

    private var updatedAt: Date? {
        if isMissingToday, let lastShared = coordinator.senderMetadata(connectionID: connectionID)?.capturedAt {
            return lastShared
        }
        return (snapshots + coordinator.snapshots(connectionID: connectionID, scope: .goals)).map(\.snapshot.capturedAt).max()
    }

    private var isMissingToday: Bool {
        connection?.scopes.contains(.today) == true
            && coordinator.snapshots(connectionID: connectionID, scope: .today).isEmpty
    }

    private func waitingGuidance(_ connection: SharingConnection) -> LocalizedStringResource {
        if connection.scopes.isEmpty { return "Cards stay hidden until both people agree to share." }
        if !connection.scopes.isEmpty && connection.scopes.isDisjoint(with: [.today, .history]) { return "Enable Today or Previous 6 Days to share daily goal results." }
        if connection.grants.contains(where: { !connection.isReady($0.scope) }) {
            return "Cards appear when both iPhones finish setting up sharing."
        }
        return "Updates arrive when the other person's iPhone sends them."
    }

}

/// One sender day with the existing calorie card and its capture time.
struct SharingCardSection: View {

    @EnvironmentObject private var settings: Settings

    @Environment(\.locale) private var locale

    @Binding var mode: GraphMode

    let snapshot: CalorieCardSnapshot
    let isToday: Bool

    init(snapshot: CalorieCardSnapshot, isToday: Bool, mode: Binding<GraphMode>) {
        self.snapshot = snapshot
        self.isToday = isToday
        _mode = mode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CardHeader(
                title: LocalizedStringKey(String(localized: snapshot.dayTitle(locale: locale))),
                secondaryTitle: isToday && snapshot.midnight != nil ? String(localized: mode == .now ? "Now" : "Midnight") : nil
            )
            .accessibilityAddTraits(.isHeader)
            if isToday && snapshot.midnight != nil && snapshot.isSupported {
                SharedTodayCalorieCard(hidesGoalStatus: settings.hideCalorieStatusIcons, mode: $mode, snapshot: snapshot)
            } else {
                SharedCalorieCard(hidesGoalStatus: settings.hideCalorieStatusIcons, snapshot: snapshot, mode: .now)
                    .padding(.bottom, RecessedCardStyle.rimDepth)
            }
            if snapshot.timeZoneIdentifier != TimeZone.current.identifier {
                Text(snapshot.senderCalendar.timeZone.localizedName(for: .generic, locale: locale)
                     ?? snapshot.timeZoneIdentifier)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

}

/// Shows pending access removal while automatic retries continue.
struct SharingPendingRemovalView: View {

    let runtime: SharingRuntime
    let coordinator: SharingCoordinator
    var connectionID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Access removal pending", systemImage: "exclamationmark.icloud")
                .font(.headline)
            if let connectionID, let connection = coordinator.connections.first(where: { $0.id == connectionID }) {
                if connection.scopes.isEmpty {
                    Text("Sharing is paused").font(.subheadline)
                } else {
                    Text("Currently sharing \(Text(connection.scopes.sharingDescription)) on this iPhone.")
                        .font(.subheadline)
                }
            } else {
                Text("Sharing was reduced or stopped on this iPhone.").font(.subheadline)
            }
            Text("iCloud access removal is still pending. The other person may still be able to access earlier cloud copies.")
                .font(.subheadline).foregroundStyle(.secondary)

        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
    }

}

/// Scope drafts distinguish immediate reductions from requested additions.
private struct SharingPermissionsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft: SharingPermissionDraft
    @State private var showsDisclosure = false
    @State private var confirmsChanges = false
    @State private var contentHeight: CGFloat = 300
    @State private var navigationHeight: CGFloat = 0

    let runtime: SharingRuntime
    let coordinator: SharingCoordinator
    let connectionID: UUID
    let peerName: String

    init(runtime: SharingRuntime, coordinator: SharingCoordinator, connection: SharingConnection) {
        self.runtime = runtime
        self.coordinator = coordinator
        connectionID = connection.id
        peerName = connection.peer(of: coordinator.identity?.id ?? "")?.displayName ?? ""
        _draft = State(initialValue: SharingPermissionDraft(connection: connection, accountID: coordinator.identity?.id))
    }

    private var scopes: Set<SharingScope> { draft.scopes }
    private var originalScopes: Set<SharingScope> { draft.acceptedScopes }
    private var additions: Set<SharingScope> { draft.additions }
    private var reductions: Set<SharingScope> { draft.reductions }
    private var connection: SharingConnection? { coordinator.connections.first { $0.id == connectionID } }
    private var hasOutgoingRequest: Bool { draft.proposal?.proposerID == coordinator.identity?.id }
    private var isStale: Bool { connection.map { !draft.matches($0) } ?? true }
    private var actionIsDisabled: Bool { runtime.isWorking || !draft.isEdited || isStale }

    private var actionTitle: LocalizedStringResource {
        if hasOutgoingRequest && scopes == originalScopes { return "Cancel request" }
        if scopes.isEmpty { return "Pause sharing" }
        if hasOutgoingRequest && !additions.isEmpty { return "Update request" }
        if originalScopes.isEmpty { return "Request to resume" }
        if !additions.isEmpty { return reductions.isEmpty ? "Send request" : "Save and send request" }
        return "Save changes"
    }

    private var confirmationTitle: LocalizedStringResource {
        if hasOutgoingRequest && scopes == originalScopes { return "Cancel request?" }
        if scopes.isEmpty { return "Pause sharing with \(peerName)?" }
        if hasOutgoingRequest && !additions.isEmpty { return "Update request?" }
        if !additions.isEmpty { return "Send a request to \(peerName)?" }
        return "Reduce sharing with \(peerName)?"
    }

    private var confirmationActionTitle: LocalizedStringResource {
        if hasOutgoingRequest && scopes == originalScopes { return "Cancel request" }
        if hasOutgoingRequest && !additions.isEmpty { return "Update request" }
        if scopes.isEmpty { return "Pause sharing" }
        if !additions.isEmpty { return reductions.isEmpty ? "Send request" : "Save and send request" }
        return "Reduce sharing"
    }

    private var confirmationRole: ButtonRole? {
        if #available(iOS 26, *) { return .confirm }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let connection, let proposal = connection.proposal,
                       proposal.recipientID != coordinator.identity?.id {
                        SharingPendingRequestSettings(
                            runtime: runtime, coordinator: coordinator, connection: connection,
                            proposal: proposal, peerName: peerName,
                            onCancelled: resetDraft
                        )
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Share with each other")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .accessibilityAddTraits(.isHeader)
                        VStack(spacing: 0) {
                            Toggle(isOn: $draft.today) { permissionLabel("Today", scope: .today) }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                            Divider().padding(.leading, 16)
                            Toggle(isOn: $draft.history) { permissionLabel("Previous 6 Days", scope: .history) }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                            Divider().padding(.leading, 16)
                            Toggle(isOn: $draft.goals) {
                                permissionLabel("Goal status & streak", scope: .goals)
                            }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                        }
                        .padding(.vertical, 4)
                        .background(.background.secondary, in: .rect(cornerRadius: 24))
                        .disabled(runtime.isWorking)
                        if draft.goals && !draft.today && !draft.history {
                            Text("Only your full streak is shared.")
                                .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16)
                        } else {
                            Text("Include goal results for shared days and your full streak. Your numeric goal target stays private.")
                                .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16)
                        }
                        Group {
                            if originalScopes.isEmpty {
                                Text("Sharing is paused")
                            } else if let connection = coordinator.connections.first(where: { $0.id == connectionID }),
                                      !connection.scopes.isEmpty, let startedAt = connection.sharingStartedAt {
                                SharingDurationView(peerName: peerName, startedAt: startedAt)
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                    }
                    Button("How sharing works", systemImage: "info.circle") { showsDisclosure = true }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(.borderless)
                    if isStale {
                        Button("Use current settings", action: resetDraft)
                            .frame(minHeight: 44)
                    }
                    if let error = runtime.actionError {
                        Text(error)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    ceil(geometry.size.height)
                } action: { contentHeight = $0 }
            }
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.safeAreaInsets.top
            } action: { navigationHeight = $0 }
            .softTopScrollEdge()
            .navigationTitle("Sharing with \(peerName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26, *) {
                        Button(role: .cancel) { dismiss() }.disabled(runtime.isWorking)
                    } else {
                        Button("Cancel", role: .cancel) { dismiss() }.disabled(runtime.isWorking)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: confirmationRole) {
                        confirmsChanges = true
                    } label: {
                        Image(systemName: additions.isEmpty ? "checkmark" : "paperplane")
                            .foregroundStyle(confirmationRole == nil ? Color.accentColor : .white)
                            .opacity(actionIsDisabled ? 0.35 : 1)
                            .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                            .animation(reduceMotion ? nil : .default, value: additions.isEmpty)
                            // Keep the symbol in SwiftUI so its replacement transition can run.
                            .overlay { Color.clear.allowsHitTesting(false) }
                    }
                    .accessibilityLabel(Text(actionTitle))
                    .disabled(actionIsDisabled)
                    .confirmationDialog(Text(confirmationTitle), isPresented: $confirmsChanges, titleVisibility: .visible) {
                        Button(confirmationActionTitle) { apply() }
                            .keyboardShortcut(.defaultAction)
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        if hasOutgoingRequest && scopes == originalScopes {
                            Text(originalScopes.sharingDescription)
                        } else if scopes.isEmpty {
                            Text("Sharing pauses for both of you. Resuming requires \(peerName)'s approval.")
                        } else if originalScopes.isEmpty {
                            Text("Ask \(peerName) to resume sharing \(Text(scopes.sharingDescription)). Sharing stays paused until the request is accepted.")
                        } else if additions.isEmpty {
                            Text("Both of you stop sharing \(Text(reductions.sharingDescription)). \(Text(scopes.sharingDescription)) stays shared. Restoring removed days requires \(peerName)'s approval.")
                        } else if reductions.isEmpty {
                            Text("Ask \(peerName) to add \(Text(additions.sharingDescription)). \(Text(originalScopes.sharingDescription)) stays shared until the request is accepted.")
                        } else {
                            Text("Request \(Text(additions.sharingDescription)) from \(peerName). \(Text(reductions.sharingDescription)) stops when you send. Adding or restoring days requires \(peerName)'s approval.")
                        }
                    }
                }
            }
            .sheet(isPresented: $showsDisclosure) { SharingDisclosureView() }
            .interactiveDismissDisabled(runtime.isWorking)
        }
        .presentationDetents([.height(contentHeight + navigationHeight)])
        .presentationDragIndicator(.visible)
        .onAppear { runtime.clearError() }
        .onChange(of: connection) {
            if !draft.isEdited { resetDraft() }
        }
    }

    private func permissionLabel(_ title: LocalizedStringResource, scope: SharingScope) -> some View {
        HStack {
            Text(title)
            if hasOutgoingRequest, draft.proposal?.scopes.contains(scope) == true,
               !originalScopes.contains(scope) {
                Text("Requested").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func resetDraft() {
        guard let connection else { return }
        draft = SharingPermissionDraft(connection: connection, accountID: coordinator.identity?.id)
        runtime.clearError()
    }

}

/// Request management lives alongside the permissions it changes.
private struct SharingPendingRequestSettings: View {

    let runtime: SharingRuntime
    let coordinator: SharingCoordinator
    let connection: SharingConnection
    let proposal: SharingProposal
    let peerName: String
    let onCancelled: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    if connection.scopes.isEmpty {
                        Text("Request to share \(Text(proposal.scopes.sharingDescription))")
                            .font(.headline)
                    } else {
                        Text("Request to add \(Text(proposal.scopes.subtracting(connection.scopes).sharingDescription))")
                            .font(.headline)
                    }
                    Text("Waiting for \(peerName)'s approval")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                Divider().padding(.horizontal, 16)
                Button(role: .destructive) {
                    Task {
                        if await runtime.perform(on: coordinator, {
                            try await coordinator.cancel(connectionID: connection.id, proposalID: proposal.id)
                        }) { onCancelled() }
                    }
                } label: {
                    Text("Cancel request")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .disabled(runtime.isWorking)
            }
            .background(.background.secondary, in: .rect(cornerRadius: 24))
            Group {
                if connection.scopes.isEmpty {
                    Text("Sharing remains paused until the request is accepted.")
                } else {
                    Text("Still sharing \(Text(connection.scopes.sharingDescription))")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
        }
    }

}

extension SharingPermissionsView {

    /// Keeps a failed draft unless its reduction was already committed locally.
    private func apply() {
        let submitted = draft
        Task {
            let saved = await runtime.perform(on: coordinator) {
                guard let current = connection, submitted.matches(current)
                else { throw SharingError.staleRevision }
                if submitted.scopes == submitted.acceptedScopes,
                   let proposal = submitted.proposal, proposal.proposerID == coordinator.identity?.id {
                    try await coordinator.cancel(connectionID: connectionID, proposalID: proposal.id)
                } else {
                    try await coordinator.changeScopes(connectionID: connectionID, to: submitted.scopes)
                }
            }
            let retained = submitted.acceptedScopes.intersection(submitted.scopes)
            let reduced = !submitted.reductions.isEmpty && connection?.scopes == retained
            if saved || reduced { dismiss() }
        }
    }

}

