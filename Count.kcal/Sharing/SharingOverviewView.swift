import SwiftUI
import UserNotifications
import Dependencies
import SQLiteData

/// Your card, shared people, and incoming requests.
struct SharingOverviewView: View {

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsInvite = false
    @State private var mode = GraphMode.now
    @State private var selectedRequest: SharingConnection?

    let runtime: SharingRuntime

    /// Keeps your own card and the people you share with in the same overview.
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            List {
                if runtime.isFixture && runtime.showsSampleLabels {
                    Text("Sample sharing").font(.caption).foregroundStyle(.secondary)
                }
                if let coordinator = runtime.coordinator {
                    SharingAccountStatusSection(runtime: runtime, coordinator: coordinator)
                    if !coordinator.pendingRevocations.isEmpty {
                        Section {
                            SharingPendingRemovalView(runtime: runtime, coordinator: coordinator)
                        }
                    }
                }
                SharingMeSection(runtime: runtime, mode: mode)
                if let coordinator = runtime.coordinator {
                    SharingPeopleSection(runtime: runtime, mode: mode)
                    SharingRequestsSection(selectedRequest: $selectedRequest, runtime: runtime, coordinator: coordinator)
                    Section {
                        Button("Invite", systemImage: "plus.circle.fill") { showsInvite = true }
                            .modifier(SharingActionAppearance())
                            .padding(.top, 14)
                            .frame(maxWidth: .infinity)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listSectionSpacing(20)
                }
            }
            .modifier(StreakAnimationScope())
            .softTopScrollEdge()
            .listSectionSpacing(30)
            .navigationTitle("Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CalorieModeToolbarButton(mode: mode) {
                        withAnimation(reduceMotion ? nil : .snappy) {
                            mode = mode == .now ? .midnight : .now
                        }
                    }
                }
            }
            .sheet(isPresented: $showsInvite) { SharingInvitationView(runtime: runtime) }
            .sheet(item: $selectedRequest) { connection in
                if let coordinator = runtime.coordinator {
                    SharingRequestConsentView(runtime: runtime, coordinator: coordinator, connectionID: connection.id)
                }
            }
            .task(id: scenePhase == .active) {
                guard scenePhase == .active else { return }
                await runtime.observeSharingScreen()
            }
        } else {
            ContentUnavailableView("Sharing is available on iPhone", systemImage: "iphone")
                .navigationTitle("Sharing")
        }
    }

}

/// Shared, neutral treatment for the centered sharing actions.
struct SharingActionAppearance: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            styled(content)
                .buttonStyle(.glass)
        } else {
            styled(content)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.primary)
        }
    }

    private func styled(_ content: Content) -> some View {
        content
            .labelStyle(SharingActionLabelStyle())
            .foregroundStyle(.primary)
            .controlSize(.regular)
    }
}

private struct SharingActionLabelStyle: LabelStyle {
    func makeBody(configuration: LabelStyleConfiguration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .font(.subheadline.weight(.medium))
            configuration.title
                .font(.body.weight(.medium))
        }
        .frame(minHeight: 32)
        .padding(.horizontal, 4)
    }
}

/// Initial loading for an empty screen and account recovery when iCloud cannot be verified.
private struct SharingAccountStatusSection: View {

    let runtime: SharingRuntime
    let coordinator: SharingCoordinator

    var body: some View {
        if !runtime.hasLoaded {
            if coordinator.connections.isEmpty,
               coordinator.pendingRevocations.isEmpty,
               runtime.pendingInvitations.isEmpty {
                Section { ProgressView("Loading sharing…") }
            }
        } else {
            switch coordinator.accountStatus {
                case .available: EmptyView()
                case .signedOut:
                    Section {
                        Label("Sign in to iCloud in Settings to use sharing", systemImage: "icloud.slash")
                        Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                            .frame(minHeight: 44)
                    }
                case .uncertain: EmptyView()
            }
        }
    }

}

/// Active and paused people, with an explanation for an empty list.
private struct SharingPeopleSection: View {

    let runtime: SharingRuntime
    let mode: GraphMode

    var body: some View {
        let people = runtime.people
        Section {
            if people.isEmpty, runtime.hasLoaded {
                ContentUnavailableView {
                    Label("Share calorie cards", systemImage: "person.2")
                } description: {
                    Text("See each other's calorie cards. Choose Today, Previous 6 Days, or both.")
                }
            } else {
                ForEach(people) { person in
                    let connection = person.connection
                    let coordinator = person.coordinator
                    NavigationLink {
                        SharingPersonDetail(runtime: runtime, coordinator: coordinator, connectionID: connection.id)
                    } label: {
                        HStack(spacing: 12) {
                            SharingPersonRow(connection: connection, coordinator: coordinator, mode: mode)
                            if person.isSample && runtime.showsSampleLabels {
                                Text("Sample")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                }
            }
        } header: { Text("People").textCase(nil) }
    }

}

/// Incoming requests remain reviewable before the recipient sets a display name.
private struct SharingRequestsSection: View {

    @Environment(\.colorScheme) private var scheme

    @Binding var selectedRequest: SharingConnection?

    let runtime: SharingRuntime
    let coordinator: SharingCoordinator

    var body: some View {
        let requests = coordinator.connections.filter { $0.proposal?.recipientID == coordinator.identity?.id }
        let preparing = runtime.pendingInvitations.filter {
            if case .awaitingInviter = $0.stage { return true }
            return false
        }
        if !requests.isEmpty || !preparing.isEmpty {
            Section {
                ForEach(preparing) { _ in
                    ProgressView("Finishing invitation…")
                }
                ForEach(requests) { connection in
                    Button { selectedRequest = connection } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(connection.peer(of: coordinator.identity?.id ?? "")?.displayName ?? "")
                                    .font(.headline).foregroundStyle(nameColor(for: connection))
                                Text(connection.requestTitle).font(.subheadline).foregroundStyle(Color.primary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(Color.secondary)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Review the requested change before accepting or declining")
                }
            } header: { Text("Invitations") }
        }
    }

    private func nameColor(for connection: SharingConnection) -> Color {
        let scope: SharingScope = connection.scopes.contains(.today) ? .today : .history
        let snapshot = coordinator.snapshots(connectionID: connection.id, scope: scope).first?.snapshot
        guard let color = snapshot?.appearance.resolvedNameColor
                ?? coordinator.senderNameColor(connectionID: connection.id) else { return .primary }
        return color.color(in: scheme)
    }

}

/// Your own local calorie card, using the same summary as shared people.
private struct SharingMeSection: View {

    @EnvironmentObject private var settings: Settings
    @State private var card = SharingOwnCard()

    let runtime: SharingRuntime
    let mode: GraphMode

    var body: some View {
        Section {
            NavigationLink {
                SharingMeDetail(runtime: runtime, card: card)
            } label: {
                let snapshot = card.snapshot(settings: settings)
                SharingCardSummary(
                    name: runtime.hasDisplayName ? runtime.displayName : String(localized: "Me"),
                    snapshot: snapshot,
                    updatedAt: snapshot?.capturedAt,
                    mode: mode,
                    status: card.day.sample.isUnavailable ? "Card unavailable" : "Loading calories…",
                    streak: card.streak,
                    placeholderNameColor: settings.weightGoal == .lose ? settings.burnedColor : settings.consumedColor
                )
            }
            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        } header: {
            Text("Me", comment: "Section for the person's own calorie card in Sharing.")
                .textCase(nil)
        }
        .modifier(SharingOwnCardLoading(card: card))
    }

}

@MainActor @Observable
/// Local card state shared by the Me row and its detail, independent of cloud publication.
private final class SharingOwnCard {

    private(set) var day: HealthInterface
    private let streakTracker: Streak
    var streak: CalorieCardSnapshot.StreakSummary? { SharingStreakBuilder.summary(streakTracker, settings: settings) }
    @ObservationIgnored private let repository: HealthRepository
    @ObservationIgnored private let settings: Settings

    init(repository: HealthRepository? = nil, settings: Settings? = nil) {
        let repository = repository ?? .shared
        let settings = settings ?? .shared
        self.repository = repository
        self.settings = settings
        streakTracker = Streak(repository: repository, settings: settings)
        day = HealthInterface(.empty(for: .now), repository: repository, settings: settings)
    }

    func snapshot(settings: Settings) -> CalorieCardSnapshot? {
        CalorieCardSnapshotBuilder.build(from: day, settings: settings)
    }

    func refresh() async {
        if !Calendar.current.isDateInToday(day.id) {
            day = HealthInterface(.empty(for: .now), repository: repository, settings: settings)
        }
        await day.updateMetrics(animated: false)
        @Dependency(\.defaultDatabase) var database
        guard let choices = try? await database.read({ try StoredDayChoice.fetchAll($0) }) else {
            streakTracker.reset()
            return
        }
        streakTracker.updateDayChoices(AppDatabase.choices(choices, sampleData: day.sample.isSampleData))
        await streakTracker.updateStreaks()
    }

}

/// Reloads the local card on foreground activity, policy changes, and day boundaries.
private struct SharingOwnCardLoading: ViewModifier {

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var settings: Settings
    @State private var calendarDay = Calendar.current.startOfDay(for: .now)

    let card: SharingOwnCard

    func body(content: Content) -> some View {
        content
            .task(id: RefreshKey(active: scenePhase == .active, day: calendarDay,
                                 policy: HealthSnapshotPolicy(settings: settings),
                                 revision: HealthRepository.shared.revision,
                                 hiddenGoalStatus: settings.hideCalorieStatusIcons)) {
                guard scenePhase == .active else { return }
                await card.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                calendarDay = Calendar.current.startOfDay(for: .now)
            }
    }

    private struct RefreshKey: Equatable {
        let active: Bool
        let day: Date
        let policy: HealthSnapshotPolicy
        let revision: String
        let hiddenGoalStatus: Bool
    }

}

/// Your card and sharing controls. Only name editing has a Save/Cancel session.
private struct SharingMeDetail: View {

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var settings: Settings
    @State private var mode = GraphMode.now
    @State private var showsNameEditor = false
    @State private var showsDisclosure = false

    let runtime: SharingRuntime
    let card: SharingOwnCard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let snapshot = card.snapshot(settings: settings) {
                    SharingCardSection(snapshot: snapshot, isToday: true, mode: $mode)
                        .padding(.horizontal, CardMetrics.horizontalInset)
                } else if card.day.sample.isUnavailable {
                    ContentUnavailableView("Card unavailable", systemImage: "heart.text.clipboard")
                } else {
                    ProgressView("Loading calories…")
                        .frame(maxWidth: .infinity)
                }

                SharingOwnSettingsCard(
                    runtime: runtime,
                    showsNameEditor: $showsNameEditor,
                    showsDisclosure: $showsDisclosure
                )

                if runtime.publisherNeedsConfirmation,
                   let coordinator = runtime.coordinator,
                   !coordinator.isPublisher {
                    Card("Updates") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose the iPhone that sends your calorie-card updates.")
                                .foregroundStyle(.secondary)
                            SharingPublisherChoice(runtime: runtime, coordinator: coordinator)
                        }
                    }
                }
                if let error = runtime.actionError {
                    Card { Text(error).foregroundStyle(.secondary) }
                }
            }
            .padding(.vertical, CardMetrics.horizontalInset)
        }
        .softTopScrollEdge()
        .background(settings.AppBackground)
        .navigationTitle("Your sharing")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(SharingOwnCardLoading(card: card))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let streak = card.streak { SharingStreakBadge(streak: streak) }
            }
        }
        .sheet(isPresented: $showsNameEditor) { SharingNameEditor(runtime: runtime) }
        .sheet(isPresented: $showsDisclosure) { SharingDisclosureView() }
        .task(id: scenePhase == .active) {
            guard scenePhase == .active else { return }
            await runtime.refreshNotificationSettings()
        }
        .onAppear { runtime.clearError() }
        .modifier(StreakAnimationScope())
    }

}

/// Own sharing controls in the app's standard settings card.
private struct SharingOwnSettingsCard: View {

    let runtime: SharingRuntime
    @Binding var showsNameEditor: Bool
    @Binding var showsDisclosure: Bool

    var body: some View {
        Card(innerPadding: 0) {
            VStack(spacing: 0) {
                Button {
                    showsNameEditor = true
                } label: {
                    HStack {
                        LabeledContent {
                            Text(runtime.hasDisplayName ? runtime.displayName : String(localized: "Add name"))
                                .foregroundStyle(.secondary)
                        } label: { Text("Name") }
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)

                Divider().padding(.horizontal, 16)

                SharingNotificationRow(runtime: runtime)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 16)

                Divider().padding(.horizontal, 16)

                Button("How sharing works", systemImage: "info.circle") { showsDisclosure = true }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(.borderless)
        }
    }

}

/// A single notification row that requests permission or opens the system settings.
private struct SharingNotificationRow: View {

    let runtime: SharingRuntime

    var body: some View {
        if runtime.notificationAuthorization == .notDetermined {
            Button {
                Task { await runtime.requestNotifications() }
            } label: {
                LabeledContent {
                    Text("Off").foregroundStyle(.secondary)
                } label: {
                    Label("Notifications", systemImage: "bell")
                }
            }
        } else {
            Link(destination: URL(string: UIApplication.openNotificationSettingsURLString)!) {
                LabeledContent {
                    Text(runtime.notificationsEnabled ? "On" : "Off").foregroundStyle(.secondary)
                } label: {
                    Label("Notifications", systemImage: "bell")
                }
            }
        }
    }

}

/// A name draft is saved explicitly and discarded when cancelled.
struct SharingNameEditor: View {

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var name: String
    @State private var contentHeight: CGFloat = 180
    @State private var navigationHeight: CGFloat = 0

    let runtime: SharingRuntime
    let onSaved: (() -> Void)?

    init(runtime: SharingRuntime, onSaved: (() -> Void)? = nil) {
        self.runtime = runtime
        self.onSaved = onSaved
        _name = State(initialValue: runtime.displayName)
    }

    private var saveIsDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || name.count > 80 || name == runtime.displayName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Name", text: $name)
                            .textContentType(.nickname)
                            .focused($isFocused)
                            .submitLabel(onSaved == nil ? .done : .continue)
                            .onSubmit { save() }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .background(.background.secondary, in: .rect(cornerRadius: 24))
                        Text("Shown to people you share with.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let error = runtime.actionError {
                        Text(error)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    ceil(geometry.size.height)
                } action: { contentHeight = $0 }
            }
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.safeAreaInsets.top
            } action: { navigationHeight = $0 }
            .softTopScrollEdge()
            .navigationTitle(runtime.hasDisplayName ? "Name" : "Your name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26, *) {
                        Button(role: .cancel) { dismiss() }
                    } else {
                        Button("Cancel", role: .cancel) { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26, *) {
                        Button(role: .confirm, action: save) {
                            Image(systemName: onSaved == nil ? "checkmark" : "arrow.right")
                        }
                            .accessibilityLabel(onSaved == nil ? "Save" : "Continue")
                            .disabled(saveIsDisabled)
                    } else {
                        Button(onSaved == nil ? "Save" : "Continue", action: save)
                            .disabled(saveIsDisabled)
                    }
                }
            }
        }
        .presentationDetents([.height(contentHeight + navigationHeight)])
        .presentationDragIndicator(.visible)
        .onAppear { runtime.clearError() }
    }

    private func save() {
        guard !saveIsDisabled else { return }
        isFocused = false
        if runtime.saveName(name) {
            if let onSaved { onSaved() } else { dismiss() }
        }
    }

}

/// Explicit publishing-device replacement after a contextual user confirmation.
struct SharingPublisherChoice: View {

    @State private var confirmsTakeover = false

    let runtime: SharingRuntime
    let coordinator: SharingCoordinator

    var body: some View {
        Button("Use this iPhone", systemImage: "iphone.and.arrow.forward") { confirmsTakeover = true }
            .frame(minHeight: 44)
            .disabled(runtime.isChangingPublisher || runtime.isManagingInvitations)
            .confirmationDialog("Use this iPhone for updates?", isPresented: $confirmsTakeover,
                                titleVisibility: .visible) {
                Button("Use this iPhone") {
                    Task { await runtime.useThisPublisher(on: coordinator) }
                }
            } message: {
                Text("Your other iPhone will stop sending calorie-card updates for this Apple Account.")
            }
    }

}

/// A person's latest balance, paired with the same energy rings as their full card.
struct SharingPersonRow: View {

    @Environment(\.colorScheme) private var scheme

    let connection: SharingConnection
    let coordinator: SharingCoordinator
    var mode: GraphMode = .now

    var body: some View {
        let snapshot = coordinator.summarySnapshot(connectionID: connection.id)
        let isMissingToday = connection.scopes.contains(.today) && snapshot == nil
        SharingCardSummary(
            name: connection.peer(of: coordinator.identity?.id ?? "")?.displayName ?? "",
            snapshot: snapshot,
            updatedAt: coordinator.summaryUpdatedAt(connectionID: connection.id),
            mode: connection.scopes.contains(.today) ? mode : .now,
            status: isMissingToday ? "No update yet today" : connection.sharingStatus,
            streak: coordinator.streak(connectionID: connection.id),
            isMissingToday: isMissingToday,
            placeholderNameColor: coordinator.senderNameColor(connectionID: connection.id)?.color(in: scheme)
        )
    }

}

/// The same rings and balance for your own card and another person's card.
private struct SharingCardSummary: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.layoutDirection) private var layoutDirection
    @EnvironmentObject private var settings: Settings
    // Preserve the original two-line summary's visible arc height.
    @ScaledMetric(relativeTo: .body) private var ringVisibleHeight: CGFloat = 49
    @ScaledMetric(relativeTo: .body) private var goalSymbolSize: CGFloat = 10
    // Keep the row stable while centering only the text that is actually shown.
    @ScaledMetric(relativeTo: .body) private var minimumContentHeight: CGFloat = 58

    let name: String
    let snapshot: CalorieCardSnapshot?
    let updatedAt: Date?
    var mode = GraphMode.now
    let status: LocalizedStringResource
    var streak: CalorieCardSnapshot.StreakSummary? = nil
    var isMissingToday = false
    var placeholderNameColor: Color? = nil

    var body: some View {
        let values = mode == .midnight ? snapshot?.midnight ?? snapshot?.now : snapshot?.now
        let goalReached = snapshot?.isSupported == true && !settings.hideCalorieStatusIcons
            && values?.energy.isEmpty == false ? values?.visibleGoalReached : nil
        HStack(alignment: .center, spacing: 12) {
            SharingPersonLayout(layoutDirection: layoutDirection, ringVisibleHeight: ringVisibleHeight) {
                if let snapshot, let values, snapshot.isSupported, !dynamicType.isAccessibilitySize {
                    CalorieCircleGraph(
                        energy: values.energy,
                        configuration: CalorieCircleConfiguration(lineWidth: 6, ringSpacing: 2, segmentGap: 2),
                        palette: CalorieGraphPalette(
                            burned: snapshot.appearance.burned.color(in: scheme),
                            consumed: snapshot.appearance.consumed.color(in: scheme),
                            empty: snapshot.appearance.graphEmpty.color(in: scheme)
                        )
                    )
                    .overlay {
                        if let goalReached {
                            Image(systemName: goalReached ? "checkmark" : "xmark")
                                .font(.system(size: goalSymbolSize, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .offset(y: 2)
                                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                        }
                    }
                    .accessibilityHidden(true)
                } else if !dynamicType.isAccessibilitySize {
                    CalorieCircleGraph(
                        energy: EnergyBalance(active: 0, resting: 0, restingRemaining: 0, consumed: 0),
                        configuration: CalorieCircleConfiguration(lineWidth: 6, ringSpacing: 2, segmentGap: 2),
                        palette: CalorieGraphPalette(
                            burned: .clear, consumed: .clear,
                            empty: settings.getGraphEmptyColor(scheme)
                        )
                    )
                    .opacity(0.65)
                    .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(nameColor)
                        .brightness(scheme == .dark && (snapshot?.isSupported == true || placeholderNameColor != nil)
                            ? BrightnessLevel.secondary.amount(in: .circlegraphMidnight) : 0)
                    if let snapshot {
                        if snapshot.isSupported, let values {
                            SharingPersonBalance(balance: values.balance, unit: snapshot.energyUnit.rawValue)
                                .font(.body.weight(.regular).monospacedDigit())
                        } else {
                            Text("Card unavailable").font(.body).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(status)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    if let updatedAt {
                        SharingUpdateLabel(date: updatedAt, style: isMissingToday ? .lastShared : .updated)
                            .font(.caption.weight(.regular))
                            .foregroundStyle(isMissingToday ? Color.red : Color.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: minimumContentHeight, alignment: .leading)
            if let streak { SharingStreakBadge(streak: streak, placement: .overview) }
        }
        .animation(rowAnimation, value: mode)
        .animation(rowAnimation, value: values)
        .animation(rowAnimation, value: streak)
        .animation(rowAnimation, value: isMissingToday)
        .accessibilityElement(children: .combine)
        .accessibilityValue(goalReached.map { $0 ? Text("Goal reached") : Text("Goal not reached") } ?? Text(""))
    }

    private var nameColor: Color {
        if let snapshot, snapshot.isSupported {
            return snapshot.appearance.resolvedNameColor.color(in: scheme)
        }
        return placeholderNameColor ?? .primary
    }

    private var rowAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: CalorieGraphAnimation.defaultDuration)
    }

}

/// Keeps the original arc proportions and optical center independently of text row count.
/// Captions and wrapped names can grow the text without enlarging the graph.
private struct SharingPersonLayout: Layout {

    let layoutDirection: LayoutDirection
    let ringVisibleHeight: CGFloat
    private let spacing: CGFloat = 16
    // The 90° opening leaves the bottom of the square unused.
    private let visibleRingHeightRatio: CGFloat = (1 + sqrt(0.5)) / 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let text = subviews.last else { return .zero }
        let ringWidth = subviews.count > 1
            ? ringVisibleHeight / visibleRingHeightRatio + spacing : 0
        let availableWidth = proposal.width.flatMap { $0.isFinite ? max(0, $0 - ringWidth) : nil }
        let textSize = text.sizeThatFits(ProposedViewSize(width: availableWidth, height: nil))
        return CGSize(width: textSize.width + ringWidth,
                      height: max(textSize.height, subviews.count > 1 ? ringVisibleHeight : 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let text = subviews.last else { return }
        let diameter = subviews.count > 1
            ? ringVisibleHeight / visibleRingHeightRatio : 0
        let ringWidth = subviews.count > 1 ? diameter + spacing : 0
        let isRightToLeft = layoutDirection == .rightToLeft
        if subviews.count > 1 {
            subviews[0].place(
                at: CGPoint(x: isRightToLeft ? bounds.maxX - diameter / 2 : bounds.minX + diameter / 2,
                            y: bounds.midY + diameter * (1 - visibleRingHeightRatio) / 2),
                anchor: .center,
                proposal: ProposedViewSize(width: diameter, height: diameter)
            )
        }
        let textWidth = max(0, bounds.width - ringWidth)
        text.place(
            at: CGPoint(x: isRightToLeft ? bounds.minX + textWidth / 2 : bounds.maxX - textWidth / 2,
                        y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(width: textWidth, height: bounds.height)
        )
    }

}

/// A neutral observation of the recorded balance, without a goal judgment.
private struct SharingPersonBalance: View {

    let balance: Int
    let unit: String

    var body: some View {
        label
            .foregroundStyle(.secondary)
            .contentTransition(.numericText(value: Double(abs(balance))))
    }

    private var label: Text {
        let amount = Text(abs(balance), format: .number).foregroundStyle(Color.primary)
        let energyUnit = Text(verbatim: unit).foregroundStyle(Color.primary)
        if balance == 0 {
            return Text("\(amount) \(energyUnit) balance")
        } else if balance > 0 {
            return Text("\(amount) \(energyUnit) deficit")
        } else {
            return Text("\(amount) \(energyUnit) surplus")
        }
    }

}

extension Set where Element == SharingScope {

    /// Localized label for the selected sharing scopes.
    var sharingDescription: LocalizedStringResource {
        switch self {
            case [.goals]: "Goal status & streak"
            case [.today, .goals]: "Today and Goal status & streak"
            case [.history, .goals]: "Previous 6 Days and Goal status & streak"
            case [.today, .history, .goals]: "Today, Previous 6 Days and Goal status & streak"
            case [.today]: "Today"
            case [.history]: "Previous 6 Days"
            case [.today, .history]: "Today and Previous 6 Days"
            default: "Sharing paused"
        }
    }

}

extension SharingConnection {

    /// The first proposal is the only transition that can produce revision one.
    var isInitialRequest: Bool { !hasAcceptedSharing && proposal != nil }

    /// Describes the addition without implying that existing permissions changed.
    var requestTitle: LocalizedStringResource {
        guard let proposal else { return "Sharing request" }
        if scopes.isEmpty {
            if isInitialRequest && proposal.scopes == [.goals] { return "Share goal status & streak" }
            return isInitialRequest ? "Share calorie cards" : "Resume sharing"
        }
        switch proposal.scopes.subtracting(scopes) {
        case [.history]: return "Add Previous 6 Days?"
        case [.today]: return "Add Today?"
        case [.goals]: return "Share goal status & streak?"
        default: return "Add sharing options?"
        }
    }

    /// Returns the visible state without implying that a refresh wakes the sender.
    var sharingStatus: LocalizedStringResource {
        if scopes.isEmpty { return "Sharing paused" }
        if grants.contains(where: { !isReady($0.scope) }) { return "Connecting" }
        if scopes.isDisjoint(with: [.today, .history]) { return "No calorie cards shared" }
        return scopes.contains(.today) ? "No update yet today" : "No shared days yet"
    }

}

#if DEBUG && targetEnvironment(simulator)
/// Isolated screenshot fixtures using the production rows and no live sharing store.
struct SharingRowStatesGallery: View {
    @EnvironmentObject private var settings: Settings
    @State private var page = ProcessInfo.processInfo.arguments.contains("--sharing-row-updates") ? 1
        : ProcessInfo.processInfo.arguments.contains("--sharing-row-me") ? 2
        : ProcessInfo.processInfo.arguments.contains("--sharing-row-goals") ? 3 : 0
    @State private var goalMode = GraphMode.now
    @State private var coordinator: SharingCoordinator?
    @State private var fixtureServer: SharingFakeServer?
    @State private var refreshVersion = 0
    @State private var examples: [Example] = []
    @State private var errorMessage: String?
    private let now = Date.now

    private struct Example: Identifiable {
        let title: String
        let page: Int
        let connection: SharingConnection
        var id: UUID { connection.id }
    }

    var body: some View {
        List {
            Section {
                Picker("Examples", selection: $page) {
                    Text("People").tag(0)
                    Text("Updates").tag(1)
                    Text("Me").tag(2)
                    Text("Goals").tag(3)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: { Text("Sample data · Production sharing rows") }

            if page == 3 {
                Section {
                    Toggle("Hide goal status icons", isOn: $settings.hideCalorieStatusIcons)
                    Picker("Mode", selection: $goalMode) {
                        Text("Now").tag(GraphMode.now)
                        Text("Midnight").tag(GraphMode.midnight)
                    }
                    .pickerStyle(.segmented)
                }
            }

            if page == 2 {
                localExample("Available", snapshot: card(goalReached: true), status: "Loading calories…")
                localExample("Loading", snapshot: nil, status: "Loading calories…")
                localExample("Unavailable", snapshot: nil, status: "Card unavailable")
                localExample("Unsupported snapshot", snapshot: card(version: 999), status: "Card unavailable")
            } else if let coordinator {
                ForEach(examples.filter { $0.page == page }) { example in
                    Section {
                        NavigationLink {
                            Text("Sample row")
                        } label: {
                            SharingPersonRow(connection: example.connection, coordinator: coordinator,
                                             mode: page == 3 ? goalMode : .now)
                        }
                        .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                    } header: { Text(verbatim: example.title).textCase(nil) }
                }
            }
            if let errorMessage { Text(verbatim: errorMessage) }
        }
        .listSectionSpacing(20)
        .navigationTitle("Sharing row states")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if page == 3 {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Sample refresh", systemImage: "arrow.clockwise") {
                        Button("Refresh with new values") {
                            Task { await refreshExamples(changesValues: true) }
                        }
                        Button("Refresh unchanged values") {
                            Task { await refreshExamples(changesValues: false) }
                        }
                    }
                    .disabled(coordinator == nil)
                }
            }
        }
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--sharing-row-light") ? .light : .dark)
        .modifier(StreakAnimationScope())
        .task { await loadExamples() }
    }

    private func localExample(_ title: String, snapshot: CalorieCardSnapshot?, status: LocalizedStringResource) -> some View {
        Section {
            NavigationLink {
                Text("Sample row")
            } label: {
                SharingCardSummary(name: "Berken", snapshot: snapshot,
                                   updatedAt: snapshot?.isSupported == true ? snapshot?.capturedAt : nil, status: status,
                                   placeholderNameColor: settings.weightGoal == .lose ? settings.burnedColor : settings.consumedColor)
            }
            .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        } header: { Text(verbatim: title).textCase(nil) }
    }

    private func card(version: Int = CalorieCardSnapshot.currentSchemaVersion, streakOnly: Bool = false,
                      goalReached: Bool? = nil, reversesProjectedGoal: Bool = false,
                      consumed: Int = 1700) -> CalorieCardSnapshot {
        let sample = SharingFixtures.snapshot(day: now, capturedAt: now, timeZone: .current,
                                              consumed: consumed, goalReached: goalReached)
        var result = CalorieCardSnapshot(
            schemaVersion: version, senderLocalDate: sample.senderLocalDate,
            timeZoneIdentifier: sample.timeZoneIdentifier, dayStart: sample.dayStart, dayEnd: sample.dayEnd,
            capturedAt: now,
            now: streakOnly ? .init(energy: EnergyBalance(active: 0, resting: 0, restingRemaining: 0, consumed: 0),
                                   visibleGoalReached: nil) : sample.now,
            midnight: streakOnly ? nil : sample.midnight.map {
                .init(energy: $0.energy,
                      visibleGoalReached: reversesProjectedGoal ? goalReached.map { !$0 } : goalReached)
            }, energyUnit: .kcal,
            appearance: CalorieCardSnapshotBuilder.appearance(settings: settings)
        )
        if streakOnly { result.streak = .init(days: 8, color: result.appearance.burned) }
        return result
    }

    private func loadExamples() async {
        guard coordinator == nil else { return }
        do {
            let store = try SharingStore()
            let server = SharingFakeServer(clock: { now })
            var state = SharingLocalState()
            var examples: [Example] = []
            let configurations: [(String, Int, Set<SharingScope>)] = [
                ("Available", 0, [.today]), ("Paused", 0, []),
                ("Goal sharing without calorie days", 0, [.goals]), ("Empty history", 0, [.history]),
                ("Available", 1, [.today]), ("Connecting", 1, [.history]),
                ("Today's update missing", 1, [.today]), ("First update pending", 1, [.today]),
                ("Goal reached now", 3, [.today, .goals]), ("Goal not reached now", 3, [.today, .goals]),
                ("Goal status hidden by sender", 3, [.today]), ("Today's update missing", 3, [.today])
            ]
            for (title, page, scopes) in configurations {
                let peer = SharingIdentity(id: UUID().uuidString, displayName: "Ommtzi")
                let publisher = UUID()
                let connection = SharingConnection(
                    id: UUID(), containerIdentifier: SharingFixtures.containerIdentifier,
                    inviter: SharingFixtures.alice, invitee: peer,
                    grants: scopes.map { SharingGrant(scope: $0, generation: UUID(),
                        readyAccountIDs: title == "Connecting" ? [] : [SharingFixtures.alice.id, peer.id]) },
                    firstAcceptedAt: now.addingTimeInterval(-7 * 86400),
                    publisherGenerations: [peer.id: publisher]
                )
                state.connections.append(connection)
                examples.append(Example(title: title, page: page, connection: connection))
                if title != "First update pending" {
                    state.senderNameColors[peer.id] = card().appearance.resolvedNameColor
                }
                if title == "Today's update missing" {
                    state.senderCalendars[peer.id] = SharingSenderCalendar(
                        timeZoneIdentifier: TimeZone.current.identifier,
                        capturedAt: now.addingTimeInterval(-4 * 86400), snapshotID: UUID(),
                        nameColor: card().appearance.resolvedNameColor
                    )
                }
                if title == "Available" || title == "Goal sharing without calorie days" || title.hasPrefix("Goal ") {
                    let goalReached: Bool? = title == "Goal reached now" ? true
                        : title == "Goal not reached now" ? false : nil
                    let snapshot = card(streakOnly: title == "Goal sharing without calorie days", goalReached: goalReached,
                                        reversesProjectedGoal: page == 3)
                    for grant in connection.grants {
                        state.snapshots.append(SharedSnapshotEnvelope(
                            connectionID: connection.id, senderID: peer.id, scope: grant.scope,
                            consentGeneration: grant.generation, publisherGeneration: publisher,
                            snapshot: snapshot.payload(for: grant.scope,
                                calorieGrant: connection.grants.first { $0.scope == .today })
                        ))
                    }
                }
            }
            server.connections = Dictionary(uniqueKeysWithValues: state.connections.map { ($0.id, $0) })
            server.snapshots = Dictionary(uniqueKeysWithValues: state.snapshots.map { ($0.id, $0) })
            try store.save(state, accountID: SharingFixtures.alice.id)
            let coordinator = SharingCoordinator(store: store, transport: server.transport(for: SharingFixtures.alice), clock: { now })
            await coordinator.verifyAccount()
            self.examples = examples
            self.coordinator = coordinator
            self.fixtureServer = server
        } catch { errorMessage = error.localizedDescription }
    }

    /// Uses the real refresh path without an explicit animation or live account data.
    private func refreshExamples(changesValues: Bool) async {
        guard let coordinator, let fixtureServer else { return }
        if changesValues {
            refreshVersion += 1
            for example in examples where example.page == 3 {
                guard let peer = example.connection.peer(of: SharingFixtures.alice.id),
                      let publisher = example.connection.publisherGenerations[peer.id] else { continue }
                let originalGoal: Bool? = example.title == "Goal reached now" ? true
                    : example.title == "Goal not reached now" ? false : nil
                let originalValues = refreshVersion.isMultiple(of: 2)
                let goalReached = originalGoal.map { originalValues ? $0 : !$0 }
                let consumed = originalValues ? 1700 : originalGoal == true ? 2000 : 1200
                let snapshot = card(goalReached: goalReached, reversesProjectedGoal: true, consumed: consumed)
                for grant in example.connection.grants {
                    let envelope = SharedSnapshotEnvelope(
                        connectionID: example.connection.id, senderID: peer.id, scope: grant.scope,
                        consentGeneration: grant.generation, publisherGeneration: publisher,
                        snapshot: snapshot.payload(for: grant.scope,
                            calorieGrant: example.connection.grants.first { $0.scope == .today })
                    )
                    fixtureServer.snapshots[envelope.id] = envelope
                }
            }
        }
        await coordinator.refresh(.changed)
    }
}
#endif
