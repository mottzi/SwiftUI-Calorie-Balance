import Network
import CloudKit
import Dependencies
import SQLiteData
import Observation
import SwiftUI
import UserNotifications

@MainActor @Observable
/// Live sharing service or explicitly selected simulator session.
final class SharingRuntime {

    /// Shared runtime used by the app lifecycle and sharing screens.
    static let shared = SharingRuntime()

    /// Coordinator for account-scoped connections and calorie cards.
    private(set) var coordinator: SharingCoordinator?

    /// Error raised while opening the local sharing database.
    private(set) var storageError: String?

    /// Error shown after a sharing action or publication pass.
    private(set) var actionError: String?

    /// Saved metadata share for the native invitation sheet.
    private(set) var invitation: SharingCloudInvitation?

    /// Whether the current invitation request completed.
    private(set) var invitationCreated = false

    /// Whether one or more sharing actions are active.
    private(set) var isWorking = false

    /// Whether the first foreground account refresh has finished.
    private(set) var hasLoaded = false

    /// CloudKit invitations that still need user action.
    private(set) var pendingInvitations: [SharingPendingInvitation] = []

    /// Imported invitation shown for review without dashboard navigation.
    var receivedInvitationID: UUID?

    /// Saved name shown to people invited by this account.
    private(set) var displayName: String

    /// Whether another publishing iPhone requires explicit replacement.
    private(set) var publisherNeedsConfirmation = false

    /// Notification permission last reported by iOS.
    private(set) var notificationAuthorization = UNAuthorizationStatus.notDetermined

    /// Whether request alerts are enabled.
    var notificationsEnabled: Bool

    /// Whether this runtime uses the simulator fixture.
    let isFixture: Bool

    #if DEBUG
    /// Adds four local people without touching live connections or CloudKit.
    var samplePeopleEnabled: Bool {
        didSet {
            guard samplePeopleEnabled != oldValue else { return }
            defaults.set(samplePeopleEnabled, forKey: "sharing.debugSamplePeople")
            if !samplePeopleEnabled { samplePeople = nil }
            Task { await refreshSamplePeople() }
        }
    }

    private(set) var samplePeople: SharingSamplePeople?
    @ObservationIgnored private var samplePeopleRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var samplePeopleRefreshAgain = false
    #endif

    /// Marketing captures omit the Debug labels while keeping sample people active.
    var showsSampleLabels: Bool {
        let mode = HealthDataMode.shared
        return !(mode.usesSampleData && mode.usesMarketingData)
    }

    /// Real and local sample people use the same screens with their own coordinator.
    var people: [SharingPerson] {
        var result = coordinator.map { coordinator in
            coordinator.connections.filter { !$0.isInitialRequest }.map {
                SharingPerson(connection: $0, coordinator: coordinator)
            }
        } ?? []
        result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        #if DEBUG
        if samplePeopleEnabled, let samples = samplePeople {
            result += samples.people
        }
        #endif
        return result
    }

    /// Live CloudKit adapter for this account.
    @ObservationIgnored private var cloud: CloudKitSharingTransport?

    /// HealthKit observer used by the active publisher.
    @ObservationIgnored private let healthObserver = SharingHealthObserver()

    #if DEBUG
    /// Fake server used by simulator sharing fixtures.
    @ObservationIgnored private var fixtureServer: SharingFakeServer?

    /// Peer coordinator used by simulator sharing fixtures.
    @ObservationIgnored private var fixturePeer: SharingCoordinator?
    #endif

    /// Defaults that store sharing preferences.
    @ObservationIgnored private let defaults: UserDefaults

    /// Health source used to build publication snapshots.
    @ObservationIgnored private let repository: HealthRepository

    /// Whether the runtime completed its first startup pass.
    @ObservationIgnored private var hasStarted = false

    /// Number of active user actions.
    @ObservationIgnored private var outstandingActions = 0

    /// Whether an invitation request is already running.
    @ObservationIgnored private var creatingInvitation = false

    /// Pending debounce task for a publication request.
    @ObservationIgnored private var scheduledPublicationTask: Task<Void, Never>?

    /// Active task that serializes publication passes.
    @ObservationIgnored private var publicationTask: Task<Void, Never>?

    /// Latest settings waiting for the active publication pass.
    @ObservationIgnored private var requestedPublicationSettings: Settings?

    /// Store that claims automatic request alerts before delivery.
    @ObservationIgnored private var notificationStore: SharingStore?

    /// Token that rejects stale invitation completions.
    @ObservationIgnored private var invitationSession = UUID()

    @ObservationIgnored private var networkMonitor: NWPathMonitor?
    @ObservationIgnored private var networkWasAvailable: Bool?
    @ObservationIgnored private var freshness = SharingFreshness()
    @ObservationIgnored private var remoteChangePending = false
    @ObservationIgnored private var remoteRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var publicationRetryTask: Task<Void, Never>?
    @ObservationIgnored private var publicationFreshness = SharingFreshness()

    /// Creates the selected live service or simulator fixture.
    private init() {

        defaults = .standard
        repository = .shared
        let savedName = UserDefaults.standard.string(forKey: "sharing.displayName") ?? ""
        displayName = savedName
        notificationsEnabled = UserDefaults.standard.bool(forKey: "sharing.notifications")
        #if DEBUG
        samplePeopleEnabled = defaults.bool(forKey: "sharing.debugSamplePeople")
        #endif
        #if DEBUG && targetEnvironment(simulator)
        isFixture = ProcessInfo.processInfo.arguments.contains("--sharing-qa")
        #else
        isFixture = false
        #endif
        do {
            if isFixture {
                #if DEBUG
                let server = SharingFakeServer()
                fixtureServer = server
                displayName = ProcessInfo.processInfo.arguments.contains("--sharing-qa-no-name") ? "" : "Alice"
                let store = try SharingStore()
                notificationStore = store
                coordinator = SharingCoordinator(store: store, transport: server.transport(for: SharingFixtures.alice))
                fixturePeer = SharingCoordinator(
                    store: try SharingStore(),
                    transport: server.transport(for: SharingFixtures.bob)
                )
                #endif
            } else {
                let transport = CloudKitSharingTransport(displayName: displayName)
                cloud = transport
                let deviceID = try SharingPublisherDevice.identifier()
                let store = try SharingStore.persistent()
                notificationStore = store
                coordinator = SharingCoordinator(store: store, transport: transport, deviceID: deviceID)
            }
        } catch {
            storageError = String(
                localized: "Sharing could not open its saved data. Close and reopen Count.kcal to try again."
            )
        }
    }

    init(
        coordinator: SharingCoordinator,
        store: SharingStore,
        repository: HealthRepository,
        defaults: UserDefaults,
        isFixture: Bool = false
    ) {
        self.coordinator = coordinator
        notificationStore = store
        self.repository = repository
        self.defaults = defaults
        self.isFixture = isFixture
        let name = defaults.string(forKey: "sharing.displayName") ?? ""
        displayName = name
        notificationsEnabled = defaults.bool(forKey: "sharing.notifications")
        #if DEBUG
        samplePeopleEnabled = defaults.bool(forKey: "sharing.debugSamplePeople")
        #endif
    }

    /// Refreshes account and invitation state, then attempts live foreground publication.
    func start(settings: Settings? = nil, refresh: SharingRefresh = .current) async {

        await refreshState(refresh)
        if !isFixture { await publishCurrentWindow(settings: settings ?? .shared) }
    }

    /// Refreshes visible sharing state without waiting for outgoing uploads.
    func refresh() async {

        await refreshState()
    }

    /// Loads account, invitation, and request state for startup or a visible refresh.
    private func refreshState(_ request: SharingRefresh = .current) async {

        #if DEBUG
        await refreshSamplePeople()
        #endif
        if !isFixture, let deadline = freshness.retryNotBefore, Date.now < deadline { return }
        defer { hasLoaded = true }
        if isFixture, !hasStarted { await prepareFixture() }
        hasStarted = true
        startConnectivityObservation()
        cloud?.displayName = displayName
        let previousGrants = readyPublicationGrants
        await coordinator?.refresh(request)
        if !readyPublicationGrants.subtracting(previousGrants).isEmpty {
            schedulePublication(settings: .shared)
        }
        if let error = coordinator?.refreshFailure {
            freshness.failed(at: .now, serverDelay: (error as? CKError)?.retryAfterSeconds)
        } else if case .available = coordinator?.accountStatus {
            freshness.succeeded(at: .now)
        } else {
            freshness.failed(at: .now)
        }
        pendingInvitations = cloud?.pendingInvitations ?? []
        await advanceFixturePeer()
        #if DEBUG
        await refreshSamplePeople()
        #endif
        updateHealthObservation()
        if coordinator?.isPublisher == true { publisherNeedsConfirmation = false }
        await refreshNotificationSettings()
        if cloud != nil { UIApplication.shared.registerForRemoteNotifications() }
        await notifyNewRequests()
    }

    /// New consent needs a first upload; incoming card changes do not.
    private var readyPublicationGrants: Set<String> {
        guard let coordinator, coordinator.isPublisher, let identity = coordinator.identity else { return [] }
        return Set(coordinator.connections.flatMap { connection in
            connection.grants.filter { !connection.removed && connection.isReady($0.scope) }.map {
                "\(identity.id)/\(connection.id)/\($0.scope.rawValue)/\($0.generation)"
            }
        })
    }

    /// Views observe the store; this shared policy bounds recovery work while visible.
    func observeSharingScreen(connectionID: UUID? = nil) async {
        defer { cloud?.prioritize(connectionID: nil) }
        while !Task.isCancelled {
            cloud?.prioritize(connectionID: connectionID)
            if isFixture || freshness.shouldRefresh(at: .now) { await refreshState() }
            if isFixture { return }
            let delay = freshness.nextRefreshDelay(at: .now)
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
        }
    }

    /// Coalesces network recovery notifications without republishing incoming cards.
    private func remoteDataChanged() {
        remoteChangePending = true
        guard remoteRefreshTask == nil else { return }
        remoteRefreshTask = Task { [weak self] in
            guard let self else { return }
            defer { self.remoteRefreshTask = nil }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            while self.remoteChangePending, !Task.isCancelled {
                self.remoteChangePending = false
                if let deadline = self.freshness.retryNotBefore, deadline > .now {
                    do { try await Task.sleep(for: .seconds(deadline.timeIntervalSinceNow)) } catch { return }
                }
                await self.refreshState(.changed)
            }
        }
    }

    /// A push starts incremental discovery; outgoing health work is independent.
    func receiveRemoteChange() async -> UIBackgroundFetchResult {
        guard !isFixture, defaults.bool(forKey: "sharing.used") else { return .noData }
        let before = coordinator?.state
        await refreshState(.changed)
        if coordinator?.refreshFailure != nil { return .failed }
        return before == coordinator?.state ? .noData : .newData
    }

    private func startConnectivityObservation() {
        guard !isFixture, networkMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let recovered = self.networkWasAvailable == false && available
                self.networkWasAvailable = available
                if recovered {
                    self.remoteDataChanged()
                    self.schedulePublication(settings: .shared)
                }
            }
        }
        networkMonitor = monitor
        monitor.start(queue: DispatchQueue(label: "com.count.kcal.sharing-connectivity"))
    }

    /// Restore observer queries before a background HealthKit delivery is processed.
    func prepareHealthObservationAtLaunch() {
        guard !isFixture, defaults.bool(forKey: "sharing.used") else { return }
        startConnectivityObservation()
        healthObserver.start { [weak self] in
            guard let self else { return }
            await self.coordinator?.verifyAccount()
            await self.publishCurrentWindow(settings: .shared)
        }
    }

    /// Whether first-use setup has a saved display name.
    var hasDisplayName: Bool { !displayName.isEmpty }

    @discardableResult
    /// Saves a valid name after its live profile metadata update succeeds.
    func saveName(_ draft: String) async -> Bool {

        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80 else { return false }
        let saved = await perform {
            if let cloud = self.cloud {
                cloud.displayName = name
                try await cloud.updateProfileName()
            }
            self.displayName = name
            if !self.isFixture {
                self.defaults.set(name, forKey: "sharing.displayName")
                self.defaults.set(true, forKey: "sharing.used")
            }
        }
        cloud?.displayName = displayName
        return saved
    }

    /// Creates one invitation through the selected sharing service.
    @discardableResult
    func invite(scopes: Set<SharingScope>) async -> Bool {

        guard hasDisplayName, !scopes.isEmpty, !creatingInvitation,
              !invitationCreated, invitation == nil else { return false }
        creatingInvitation = true
        defer { creatingInvitation = false }
        let session = invitationSession
        return await perform {
            #if DEBUG
            if self.isFixture && ProcessInfo.processInfo.arguments.contains("--sharing-qa-slow-invite") {
                try await Task.sleep(for: .seconds(5))
            }
            #endif
            guard session == self.invitationSession else { throw CancellationError() }
            guard let coordinator = self.coordinator else { throw SharingError.accountUnavailable }
            try await coordinator.preparePublisher()
            if self.isFixture {
                _ = try await coordinator.propose(to: SharingFixtures.bob, scopes: scopes)
            } else {
                guard let cloud = self.cloud else { throw SharingError.unavailable }
                let invitation = cloud.invitation(id: session, scopes: scopes)
                guard session == self.invitationSession else { return }
                self.invitation = invitation
            }
            guard session == self.invitationSession else { return }
            self.invitationCreated = self.isFixture
        }
    }

    /// Clears the invitation and invalidates any pending invitation session.
    func clearInvitation() {
        invitationSession = UUID()
        invitation = nil
        invitationCreated = false
    }

    /// Reloads a pending invitation for native recipient selection and delivery.
    func resumeInvitation(id: UUID) async -> SharingCloudInvitation? {

        var invitation: SharingCloudInvitation?
        await perform {
            guard let cloud = self.cloud else { throw SharingError.unavailable }
            invitation = try await cloud.invitation(for: id)
        }
        return invitation
    }

    /// Refreshes the selected recipient after the system sheet completes.
    func finishInvitation(error: Error?) async {

        if !isFixture {
            invitationCreated = invitation?.share != nil
            if !invitationCreated { invitation = nil }
        }
        if let error {
            await perform { throw error }
            return
        }
        await start(refresh: .changed)
    }

    /// Clears the latest sharing action error.
    func clearError() { actionError = nil }

    /// Cancels a pending invitation and refreshes the overview.
    func cancelPendingInvitation(id: UUID) async {
        await perform { try await self.cloud?.cancelPendingInvitation(id: id) }
        await start(refresh: .changed)
    }

    @discardableResult
    /// Reports local action completion and keeps failed forms available for retry.
    func perform(on actionCoordinator: SharingCoordinator? = nil, _ action: () async throws -> Void) async -> Bool {

        #if DEBUG
        let isSampleAction = actionCoordinator != nil && actionCoordinator === samplePeople?.coordinator
        #endif
        outstandingActions += 1
        isWorking = true; actionError = nil
        defer {
            outstandingActions -= 1
            isWorking = outstandingActions > 0
            pendingInvitations = cloud?.pendingInvitations ?? []
        }
        do {
            try await action()
            #if DEBUG
            if isSampleAction {
                await refreshSamplePeople()
                return true
            }
            #endif
            await advanceFixturePeer()
            #if DEBUG
            await refreshSamplePeople()
            #endif
            updateHealthObservation()
            schedulePublication(settings: .shared)
            if coordinator?.isPublisher == true { publisherNeedsConfirmation = false }
            return true
        }
        catch {
            if error as? SharingError == .publisherNotOwned { publisherNeedsConfirmation = true }
            actionError = SharingError.message(for: error)
            return false
        }
    }

    /// Imports CloudKit invitation metadata on iPhone and refreshes connections.
    func importInvitation(_ metadata: CKShare.Metadata) async {

        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        guard let cloud else { return }
        defaults.set(true, forKey: "sharing.used")
        await perform { receivedInvitationID = try await cloud.importInvitation(metadata) }
        await coordinator?.refresh(.changed)
        pendingInvitations = cloud.pendingInvitations
    }

    /// Imports an invitation URL on iPhone and refreshes connections.
    func importInvitation(url: URL) async {

        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        guard let cloud else { return }
        defaults.set(true, forKey: "sharing.used")
        await perform { receivedInvitationID = try await cloud.importInvitation(url: url) }
        await coordinator?.refresh(.changed)
        pendingInvitations = cloud.pendingInvitations
    }

    /// Reads the current system permission when returning from notification settings.
    func refreshNotificationSettings() async {
        guard !isFixture else { return }
        notificationAuthorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsEnabled = notificationAuthorization == .authorized || notificationAuthorization == .provisional
    }

    /// Requests notification authorization for incoming sharing proposals.
    func requestNotifications() async {

        guard !isFixture else { return }
        notificationAuthorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard notificationAuthorization == .notDetermined else { return }
        do {
            notificationsEnabled = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            if !isFixture { defaults.set(notificationsEnabled, forKey: "sharing.notifications") }
            notificationAuthorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        } catch { notificationsEnabled = false }
    }

    /// An ordinary foreground refresh is also the fallback for silent-push delivery.
    func refreshIfUsed(settings: Settings, refresh: SharingRefresh = .current) async {
        guard !isFixture,
              UIDevice.current.userInterfaceIdiom == .phone,
              defaults.bool(forKey: "sharing.used")
            else { return }
        await start(settings: settings, refresh: refresh)
    }

    /// Verifies an account notification before refreshing its sharing state.
    func accountDidChange(settings: Settings) async {

        guard !isFixture, UIDevice.current.userInterfaceIdiom == .phone,
              defaults.bool(forKey: "sharing.used") else { return }
        freshness = SharingFreshness()
        publicationFreshness = SharingFreshness()
        publicationRetryTask?.cancel()
        await coordinator?.verifyAccount()
        await refreshIfUsed(settings: settings, refresh: .changed)
    }

    /// Prunes expired proposals and snapshots while the app stays active.
    func expireWhileActive() async {

        guard !isFixture,
              UIDevice.current.userInterfaceIdiom == .phone,
              defaults.bool(forKey: "sharing.used")
            else { return }
        while !Task.isCancelled {
            let next = coordinator?.nextExpiryDate() ?? Date.now.addingTimeInterval(60)
            do { try await Task.sleep(for: .seconds(max(0.01, next.timeIntervalSinceNow))) }
            catch { return }
            coordinator?.purgeExpiredCache()
            pendingInvitations.removeAll {
                if case .awaitingRecipient(_, _, let expiry, _) = $0.stage { return expiry <= Date.now }
                return false
            }
        }
    }

    /// Debounces publication requests and records settings for an active pass.
    func schedulePublication(settings: Settings) {

        guard !isFixture, defaults.bool(forKey: "sharing.used") else { return }
        // an active pass owns its network work so a new trigger requests one more pass with current inputs
        if publicationTask != nil {
            requestedPublicationSettings = settings
            return
        }
        if let deadline = publicationFreshness.retryNotBefore, Date.now < deadline { return }
        scheduledPublicationTask?.cancel()
        scheduledPublicationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.scheduledPublicationTask = nil
            await self?.publishCurrentWindow(settings: settings)
        }
    }

    /// Runs publication passes and awaits any coalesced follow-up.
    func publishCurrentWindow(settings: Settings) async {

        if let deadline = publicationFreshness.retryNotBefore, Date.now < deadline { return }
        scheduledPublicationTask?.cancel()
        scheduledPublicationTask = nil
        requestedPublicationSettings = settings
        if let publicationTask {
            await publicationTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.publicationTask = nil }
            while let settings = self.requestedPublicationSettings {
                self.requestedPublicationSettings = nil
                await self.publishWindow(settings: settings)
            }
        }
        publicationTask = task
        // wait for the active pass and any coalesced follow-up before returning
        await task.value
    }

}

extension SharingRuntime {

    /// Starts HealthKit observation only while this device owns a verified live lease.
    private func updateHealthObservation() {
        if cloud != nil, let coordinator, coordinator.isPublisher,
           case .available = coordinator.accountStatus {
            healthObserver.start { [weak self] in await self?.publishCurrentWindow(settings: .shared) }
        } else { healthObserver.stop() }
    }

    /// Reads permitted days and publishes only measurements from the current policy.
    private func publishWindow(settings: Settings) async {

        guard let coordinator, coordinator.isPublisher,
              case .available = coordinator.accountStatus else { return }
        let lease = coordinator.state.publisherLease
        let policy = HealthSnapshotPolicy(settings: settings)
        let sourceRevision = repository.revision
        let calendar = Calendar.current
        let now = Date.now
        let needsCards = coordinator.connections.contains { !$0.scopes.intersection([.today, .history]).isEmpty }
        let needsHistory = coordinator.connections.contains { $0.scopes.contains(.history) }
        let needsStreak = coordinator.connections.contains { $0.scopes.contains(.streaks) }
        let offsets = needsCards ? [0] + (needsHistory ? (1...SharingDateWindow.historyDayCount).map { -$0 } : []) : []
        @Dependency(\.defaultDatabase) var database
        guard let choices = try? await database.read({ try StoredDayChoice.fetchAll($0) }) else { return }
        var streakSnapshot: CalorieCardSnapshot?
        if needsStreak {
            let summary = await SharingStreakBuilder.build(
                repository: repository, settings: settings, choices: choices,
                sampleData: repository.usesSampleMeasurements
            )
            if sourceRevision == repository.revision, policy == HealthSnapshotPolicy(settings: settings),
               Calendar.current.isDateInToday(now), calendar.timeZone == Calendar.current.timeZone,
               coordinator.state.publisherLease == lease {
                streakSnapshot = SharingStreakBuilder.snapshot(summary, settings: settings, now: now)
            }
        }
        let excludedIDs = Set(choices.filter { $0.choice == DayChoice.excluded.rawValue }.map(\.id))
        var snapshots: [CalorieCardSnapshot] = []
        for offset in offsets {
            guard !Task.isCancelled, coordinator.state.publisherLease == lease,
                  case .available = coordinator.accountStatus,
                  let date = calendar.date(byAdding: .day, value: offset, to: now) else {
                snapshots.removeAll()
                streakSnapshot = nil
                break
            }
            let sample = await repository.fetchDailySnapshot(for: date, policy: policy, now: now)
            // abort if the source, unit, calendar, or publisher authority changed
            guard policy == HealthSnapshotPolicy(settings: settings),
                  sourceRevision == repository.revision,
                  calendar.timeZone == Calendar.current.timeZone,
                  coordinator.state.publisherLease == lease,
                  case .available = coordinator.accountStatus else {
                snapshots.removeAll()
                streakSnapshot = nil
                break
            }
            guard var snapshot = CalorieCardSnapshotBuilder.build(
                sample: sample,
                settings: settings,
                calendar: calendar
            ) else { continue }
            snapshot.isExcluded = excludedIDs.contains(AppDatabase.recordID(for: sample.date, sampleData: sample.isSampleData))
            snapshots.append(snapshot)
        }
        // ordinary failures do not stop other dates or peers, and every pass tries retention cleanup
        let failureMessage = String(localized: "Sharing could not finish updating. Count.kcal will retry.")
        if settings.hideCalorieStatusIcons { streakSnapshot?.streak = nil }
        do {
            try await coordinator.publish(snapshots: snapshots, streakSnapshot: streakSnapshot)
            publicationFreshness.succeeded(at: .now)
            publicationRetryTask?.cancel()
            publicationRetryTask = nil
            if actionError == failureMessage { actionError = nil }
        } catch {
            actionError = failureMessage
            publicationFreshness.failed(at: .now, serverDelay: (error as? CKError)?.retryAfterSeconds)
            publicationRetryTask?.cancel()
            let delay = max(1, publicationFreshness.retryNotBefore?.timeIntervalSinceNow ?? 5)
            publicationRetryTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard !Task.isCancelled, let self else { return }
                // Suspension is allowed; foreground/HealthKit delivery also retries this work.
                await self.publishCurrentWindow(settings: settings)
            }
        }
    }

    /// Claims a verified incoming proposal before adding its local notification.
    private func notifyNewRequests() async {

        guard let notificationStore else { return }
        let now = Date.now
        try? notificationStore.expireRequestAlerts(now: now)
        guard !isFixture, notificationsEnabled, let coordinator,
              case .available(let account) = coordinator.accountStatus,
              coordinator.identity?.id == account.id else { return }
        for proposal in coordinator.connections.compactMap(\.proposal) {
            guard (try? notificationStore.claimRequestAlert(
                proposal,
                verifiedAccountID: account.id,
                now: now
            )) == true else { continue }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Sharing request")
            content.body = String(localized: "Open Sharing in Count.kcal to review a request.")
            content.sound = .default
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(
                    identifier: "\(account.id):\(proposal.id.uuidString)",
                    content: content,
                    trigger: nil
                )
            )
        }
    }
}

extension SharingRuntime {

    #if DEBUG
    /// Serializes sample setup, including rapid toggles and live connection changes.
    func refreshSamplePeople() async {
        if let samplePeopleRefreshTask {
            samplePeopleRefreshAgain = true
            await samplePeopleRefreshTask.value
            return
        }
        let task = Task {
            defer { samplePeopleRefreshTask = nil }
            repeat {
                samplePeopleRefreshAgain = false
                guard samplePeopleEnabled, !isFixture else {
                    samplePeople = nil
                    return
                }
                do {
                    if samplePeople == nil { samplePeople = try SharingSamplePeople() }
                    try await samplePeople?.refresh()
                } catch {
                    actionError = String(localized: "Sample sharing could not be loaded.")
                }
            } while samplePeopleRefreshAgain
        }
        samplePeopleRefreshTask = task
        await task.value
    }
    #endif

    /// Synchronizes the synthetic peer after a fixture action.
    private func advanceFixturePeer() async {
        #if DEBUG
        guard isFixture, let coordinator, let peer = fixturePeer else { return }
        do { try await SharingFixtures.synchronize(peer: peer, recipient: coordinator, now: .now) }
        catch { actionError = String(localized: "Sample sharing could not be loaded.") }
        #endif
    }

    /// Creates the selected fake connection and sample cards for simulator runs.
    private func prepareFixture() async {

        #if DEBUG
        guard let coordinator, let peer = fixturePeer else { return }
        await coordinator.verifyAccount()
        await peer.verifyAccount()
        do {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--sharing-qa-empty") { return }
            var bob = SharingFixtures.bob
            if arguments.contains("--sharing-qa-long-name") { bob.displayName = "Alexandria Charlotte von Winterthur" }
            let scopes: Set<SharingScope> = arguments.contains("--sharing-qa-outgoing-request") ? [.history]
                : arguments.contains("--sharing-qa-expansion-request") ? [.today]
                : arguments.contains("--sharing-qa-history") ? [.history] : [.today, .history]
            let id = try await coordinator.propose(to: bob, scopes: scopes)
            await peer.refresh()
            if let proposal = peer.connections.first(where: { $0.id == id })?.proposal {
                try await peer.accept(connectionID: id, proposalID: proposal.id)
            }
            await coordinator.refresh()
            await peer.refresh()
            await coordinator.refresh()
            try await coordinator.takeOverPublisher()
            try await peer.takeOverPublisher()
            try await SharingFixtures.synchronize(peer: peer, recipient: coordinator, now: .now)
            if arguments.contains("--sharing-qa-pending") { fixtureServer?.failRevocationDirections = [.incoming] }
            if arguments.contains("--sharing-qa-outgoing-request") {
                try await coordinator.changeScopes(connectionID: id, to: [.today, .history])
            } else if arguments.contains("--sharing-qa-expansion-request") {
                try await peer.changeScopes(connectionID: id, to: [.today, .history])
                await coordinator.refresh()
            } else if arguments.contains("--sharing-qa-request") {
                try await peer.changeScopes(connectionID: id, to: [])
                await coordinator.refresh()
                try await peer.changeScopes(connectionID: id, to: [.today, .history])
                await coordinator.refresh()
            }
        } catch { actionError = String(localized: "Sample sharing could not be loaded.") }
        #endif
    }

}
