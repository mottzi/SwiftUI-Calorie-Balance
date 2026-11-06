import Foundation
import Dependencies
import SQLiteData
import SwiftUI
import Testing
import UIKit
@testable import Count_kcal

@Suite(.serialized)
/// Calorie snapshot freshness, privacy, date windows, and card rendering coverage.
struct SharingSnapshotTests {

    @Test
    func streakSummaryRoundTripsAndRejectsInvalidCounts() throws {
        let now = date("2026-11-01T12:00:00Z")
        var snapshot = SharingFixtures.snapshot(day: now, capturedAt: now)
        snapshot.streak = .init(days: 123, color: snapshot.appearance.burned)
        let received = try JSONDecoder().decode(CalorieCardSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(received.streak == snapshot.streak)
        #expect(received.isSupported)
        #expect(received.payload(for: .today).streak == nil)
        #expect(received.payload(for: .history).streak == nil)
        let summaryOnly = received.payload(for: .goals)
        #expect(summaryOnly.streak?.days == 123)
        #expect(summaryOnly.now.energy.isEmpty)
        #expect(SharingDateWindow.permits(summaryOnly, scope: .goals, now: now))
        for invalid in [-1, 201] {
            snapshot.streak = .init(days: invalid, color: snapshot.appearance.burned)
            #expect(!snapshot.isSupported)
        }
    }

    @Test
    /// Formats Today and Yesterday in the sender's calendar across recipient date boundaries.
    func sharedDateTitlesUseTheSenderDay() throws {

        let now = date("2026-10-24T17:00:00Z")
        let snapshot = SharingFixtures.snapshot(day: now, capturedAt: now,
                                                timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        let locale = Locale(identifier: "en_US")
        #expect(snapshot.senderLocalDate == "2026-10-25")
        #expect(String(localized: snapshot.dayTitle(now: now, locale: locale)) == "Today")
        #expect(String(localized: snapshot.dayTitle(now: now.addingTimeInterval(86400), locale: locale))
                == "Yesterday")
        let german = Locale(identifier: "de_DE")
        #expect(String(localized: snapshot.dayTitle(now: now, locale: german)) == "Heute")
        #expect(snapshot.senderCalendar.timeZone.identifier == "Asia/Tokyo")
    }

    /// Keeps older sender dates visible in each supported language.
    @Test(arguments: ["en_US", "de_DE", "es_ES", "fr_FR", "zh_Hans"])
    func olderSharedDatesKeepTheirLocalizedText(_ identifier: String) {

        let now = date("2026-10-25T12:00:00Z")
        let day = date("2026-10-22T12:00:00Z")
        let snapshot = SharingFixtures.snapshot(day: day, capturedAt: now)
        let locale = Locale(identifier: identifier)
        let calendar = snapshot.senderCalendar
        let format = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale,
                                      calendar: calendar, timeZone: calendar.timeZone)
        let title = String(localized: snapshot.dayTitle(now: now, locale: locale))
        #expect(!title.isEmpty)
        #expect(title == snapshot.dayStart.formatted(format))
    }

    @Test
    /// Ensures failed and unloaded reads do not create zero-valued cards.
    func failedAndUnloadedReadsDoNotBecomeZeroCards() {

        let calendar = calendar("Europe/Zurich")
        let date = date("2026-10-24T10:00:00Z")
        #expect(build(.empty(for: date), calendar: calendar) == nil)
        #expect(build(.unavailable(for: date), calendar: calendar) == nil)
        var validZero = HealthData.empty(for: date)
        validZero.lastDataSync = date
        let snapshot = build(validZero, calendar: calendar)
        #expect(snapshot?.now.burned == 0)
        #expect(snapshot?.now.visibleGoalReached == nil)
        #expect(snapshot?.capturedAt == date)
    }

    @MainActor @Test
    /// Ensures publication snapshots match the current unit and source policy.
    func publicationSnapshotRequiresTheCurrentUnitAndSourcePolicy() async throws {

        let database = try AppDatabase.makeDatabase(path: nil)
        await withDependencies { $0.defaultDatabase = database } operation: {

            let settings = Settings.shared
            let original = (settings.energyUnit, settings.dataSource, settings.customCalActive, settings.customCalPassive)
            defer {
                settings.energyUnit = original.0
                settings.dataSource = original.1
                settings.customCalActive = original.2
                settings.customCalPassive = original.3
            }
            settings.energyUnit = .kcal
            settings.dataSource = .apple
            let repository = HealthRepository(source: SampleHealthDataSource(now: .now))
            let day = HealthInterface(.empty(for: .now), repository: repository, settings: settings)
            #expect(!day.hasCurrentSnapshot)
            await day.updateMetrics(animated: false)
            #expect(day.hasCurrentSnapshot)
            let oldCapture = day.sample.lastDataSync
            settings.energyUnit = .kJ
            #expect(day.hasLoadedSnapshot)
            #expect(!day.hasCurrentSnapshot)
            #expect(day.sample.lastDataSync == oldCapture)
            await day.updateMetrics(animated: false)
            #expect(day.hasCurrentSnapshot)
            settings.customCalActive = 500
            settings.customCalPassive = 1500
            settings.dataSource = .custom
            #expect(!day.hasCurrentSnapshot)
            await day.updateMetrics(animated: false)
            #expect(day.hasCurrentSnapshot)
            settings.customCalActive = 600
            #expect(!day.hasCurrentSnapshot)
            await day.updateMetrics(animated: false)
            #expect(day.hasCurrentSnapshot)
        }
    }

    @Test
    /// Verifies both energy ranges use one schema and omit private goal values.
    func nowAndMidnightUseOneVersionAndHidePrivateGoalThresholds() throws {

        let capturedAt = date("2026-10-24T10:00:00Z")
        var sample = HealthData.example(for: capturedAt)
        sample.lastDataSync = capturedAt
        let snapshot = try #require(build(sample)).withoutGoalInformation()
        #expect(snapshot.now.energy == sample.now)
        #expect(snapshot.midnight?.energy == sample.midnight)
        #expect(snapshot.now.visibleGoalReached == nil)
        #expect(snapshot.midnight?.visibleGoalReached == nil)
        let data = try JSONEncoder().encode(snapshot)
        let json = try #require(String(data: data, encoding: .utf8))
        for excluded in ["balanceGoal", "weightGoal", "protein", "steps", "burnedPassive7", "Settings"] {
            #expect(!json.contains(excluded))
        }
        #expect(try JSONDecoder().decode(CalorieCardSnapshot.self, from: data) == snapshot)
    }

    @Test
    /// Verifies visible goal status follows the sender's snapshot policy.
    func visibleGoalIsResolvedUsingTheSenderPolicy() throws {

        let capturedAt = date("2026-10-24T10:00:00Z")
        var sample = HealthData.example(for: capturedAt)
        sample.lastDataSync = capturedAt
        var policy = HealthSnapshotPolicy()
        policy.energyUnit = .kJ
        policy.balanceGoal = 500
        policy.isLoss = true
        let snapshot = try #require(CalorieCardSnapshotBuilder.build(
            sample: sample,
            policy: policy,
            appearance: appearance,
            calendar: calendar("Europe/Zurich")
        ))
        #expect(snapshot.energyUnit == .kJ)
        #expect(snapshot.now.visibleGoalReached == sample.now.meetsGoal(500, isLoss: true))
        #expect(snapshot.midnight?.visibleGoalReached == sample.midnight.meetsGoal(500, isLoss: true))
        #expect(snapshot.now.burned == sample.now.burned)
    }

    @Test(arguments: [("2026-03-29T10:00:00Z", 23), ("2026-10-25T10:00:00Z", 25)])
    /// Verifies sender-local day lengths across both daylight-saving transitions.
    func senderDaysFollowDaylightSaving(input: (String, Int)) throws {

        let capturedAt = date(input.0)
        var sample = HealthData.example(for: capturedAt)
        sample.lastDataSync = capturedAt
        let snapshot = try #require(build(sample))
        #expect(snapshot.dayEnd.timeIntervalSince(snapshot.dayStart) == Double(input.1 * 3600))
        #expect(snapshot.timeZoneIdentifier == "Europe/Zurich")
        #expect(snapshot.isSupported)
    }

    @Test
    /// Verifies historical cards contain recorded totals without a midnight value.
    func historicalCardsHaveOnlyRecordedTotals() throws {

        let sampleDate = date("2026-10-23T10:00:00Z")
        var sample = HealthData.example(for: sampleDate)
        sample.lastDataSync = date("2026-10-24T10:00:00Z")
        let snapshot = try #require(build(sample))
        #expect(snapshot.senderLocalDate == "2026-10-23")
        #expect(snapshot.midnight == nil)
        #expect(snapshot.now.restingRemaining == 0)
        #expect(snapshot.now.burned == sample.burnedActive + sample.burnedPassive)
    }

    @Test
    /// Rejects payloads with unknown schemas or inconsistent calorie values.
    func malformedOrUnknownRemotePayloadIsUnsupported() throws {

        let capturedAt = date("2026-10-24T10:00:00Z")
        var sample = HealthData.example(for: capturedAt)
        sample.lastDataSync = capturedAt
        let snapshot = try #require(build(sample))
        let encoded = try JSONEncoder().encode(snapshot)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["schemaVersion"] = 999
        let future = try JSONDecoder().decode(
            CalorieCardSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(!future.isSupported)
        object["schemaVersion"] = 1
        var now = try #require(object["now"] as? [String: Any])
        now["burned"] = 1
        object["now"] = now
        let inconsistent = try JSONDecoder().decode(
            CalorieCardSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(!inconsistent.isSupported)
    }

    @MainActor @Test
    /// Compares local and shared card pixels across appearance and text sizes.
    func sharedCardMatchesNativeCardWithoutRecipientSettings() throws {

        let settings = Settings.shared
        let capturedAt = date("2026-10-24T10:00:00Z")
        var sample = HealthData.example(for: capturedAt)
        sample.lastDataSync = capturedAt
        let snapshot = try #require(CalorieCardSnapshotBuilder.build(sample: sample, settings: settings))
        let day = HealthInterface(sample)
        for mode in [GraphMode.now, .midnight] {
            for scheme in [ColorScheme.light, .dark] {
                for size in [DynamicTypeSize.large, .accessibility3, .accessibility5] {
                    let local = try pixels(
                        CaloriesCard(mode: mode).environment(day).environmentObject(settings),
                        scheme: scheme,
                        size: size
                    )
                    // no Settings or HealthInterface is injected into the shared renderer
                    let shared = try pixels(SharedCalorieCard(hidesGoalStatus: settings.hideCalorieStatusIcons, snapshot: snapshot, mode: mode), scheme: scheme, size: size)
                    #expect(local.count == shared.count)
                    let mismatch = zip(local, shared).filter { abs(Int($0) - Int($1)) > 3 }.count
                    #expect(Double(mismatch) / Double(max(1, local.count)) < 0.003)
                }
            }
        }
    }

    @Test
    func sharedWeekUsesSevenSenderDatesAndStopsStreakAtGapsOrExclusions() throws {
        let now = date("2026-10-25T22:30:00Z")
        let calendar = calendar("Asia/Tokyo")
        func card(_ offset: Int, excluded: Bool = false, goal: Bool? = true) -> CalorieCardSnapshot {
            SharingFixtures.snapshot(
                day: calendar.date(byAdding: .day, value: offset, to: now)!,
                capturedAt: now, timeZone: calendar.timeZone,
                includeProjection: offset == 0, goalReached: goal, isExcluded: excluded
            )
        }
        let snapshots = [card(0), card(-1), card(-2), card(-3, excluded: true), card(-4), card(-6), card(-7)]
        let week = SharedCalorieWeek(snapshots: snapshots, now: now)
        #expect(week.days.count == 7)
        #expect(week.calendar.timeZone == calendar.timeZone)
        #expect(week.days.compactMap(\.snapshot).count == 6)
        #expect(week.days.last?.snapshot?.senderLocalDate == "2026-10-26")
        #expect(week.days.first?.snapshot?.senderLocalDate == "2026-10-20")
        #expect(week.days.filter(\.isInCurrentStreak).compactMap { $0.snapshot?.senderLocalDate }
            == ["2026-10-24", "2026-10-25"])
        let gap = SharedCalorieWeek(snapshots: [card(0), card(-2)], now: now)
        #expect(gap.days.allSatisfy { !$0.isInCurrentStreak })
        let hidden = SharedCalorieWeek(snapshots: [card(0), card(-1, goal: nil), card(-2)], now: now)
        #expect(hidden.days.allSatisfy { !$0.isInCurrentStreak })
    }

    @Test
    func olderSnapshotsDecodeWithoutNewPresentationFields() throws {
        let now = date("2026-10-25T10:00:00Z")
        let snapshot = SharingFixtures.snapshot(day: now, capturedAt: now)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        object.removeValue(forKey: "isExcluded")
        object.removeValue(forKey: "streak")
        object.removeValue(forKey: "goalResult")
        var appearance = try #require(object["appearance"] as? [String: Any])
        appearance.removeValue(forKey: "labelBackground")
        appearance.removeValue(forKey: "pageBackground")
        appearance.removeValue(forKey: "nameColor")
        object["appearance"] = appearance
        let decoded = try JSONDecoder().decode(CalorieCardSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.isSupported)
        #expect(decoded.appearance.labelBackground == nil)
        #expect(decoded.appearance.pageBackground == nil)
        #expect(decoded.appearance.nameColor == nil)
        #expect(decoded.appearance.resolvedNameColor == decoded.appearance.burned)
        #expect(decoded.isExcluded == nil)
        #expect(decoded.streak == nil)
        #expect(decoded.goalResult == nil)
    }

    @MainActor @Test
    func senderNameColorUsesGoalAccentAndSurvivesTransfer() throws {
        let now = date("2026-11-06T12:00:00Z")
        let jonas = try #require(SharingSamplePeople.snapshots(profile: .lowActivity, now: now).first)
        let maya = try #require(SharingSamplePeople.snapshots(profile: .active, now: now).first)
        #expect(jonas.appearance.resolvedNameColor == jonas.appearance.consumed)
        #expect(jonas.appearance.resolvedNameColor != jonas.appearance.burned)
        #expect(maya.appearance.resolvedNameColor == maya.appearance.burned)
        let settings = Settings.shared
        let localAppearance = CalorieCardSnapshotBuilder.appearance(settings: settings)
        #expect(localAppearance.resolvedNameColor == (settings.weightGoal == .lose
            ? localAppearance.burned : localAppearance.consumed))

        // Name appearance travels with calorie permissions, without requiring Streak.
        let received = try JSONDecoder().decode(
            CalorieCardSnapshot.self, from: JSONEncoder().encode(jonas.payload(for: .today))
        )
        #expect(received.isSupported)
        #expect(received.streak == nil)
        #expect(received.appearance.resolvedNameColor == jonas.appearance.consumed)
        var invalid = received.appearance
        invalid.nameColor = .init(light: .init(red: .nan, green: 0, blue: 0),
                                 dark: .init(red: 0, green: 0, blue: 0))
        #expect(!invalid.isValid)
    }

    @MainActor @Test
    func senderBackgroundSurvivesTransferAndRecipientChanges() throws {
        let settings = Settings.shared
        let original = settings.appBackground
        defer { settings.appBackground = original }
        var sample = HealthData.example(for: .now)
        sample.lastDataSync = .now
        for background in [Settings.AppBackgrounds.black, .dark, .light] {
            settings.appBackground = background
            let snapshot = try #require(CalorieCardSnapshotBuilder.build(sample: sample, settings: settings))
            let encoded = try JSONEncoder().encode(snapshot)
            let received = try JSONDecoder().decode(CalorieCardSnapshot.self, from: encoded)
            settings.appBackground = background == .black ? .light : .black
            #expect(received.isSupported)
            #expect(received.appearance.pageBackground == CalorieCardSnapshotBuilder.adaptive(background.pageColor))
            #expect(received.appearance.cardBackground == CalorieCardSnapshotBuilder.adaptive(background.cardColor))
            #expect(received.appearance.pageBackground != CalorieCardSnapshotBuilder.adaptive(settings.AppBackground))
        }
        var invalid = CalorieCardSnapshotBuilder.appearance(settings: settings)
        invalid.pageBackground = .init(light: .init(red: .nan, green: 0, blue: 0),
                                       dark: .init(red: 0, green: 0, blue: 0))
        #expect(!invalid.isValid)
    }

    @MainActor @Test
    func sharedLabelsKeepSenderAppearanceAfterRecipientPreferencesChange() throws {
        let settings = Settings.shared
        let original = (settings.showCalorieLabelBackgrounds, settings.calorieLabelBackground)
        defer {
            settings.showCalorieLabelBackgrounds = original.0
            settings.calorieLabelBackground = original.1
        }
        settings.showCalorieLabelBackgrounds = true
        settings.calorieLabelBackground = .light
        var sample = HealthData.example(for: .now)
        sample.lastDataSync = .now
        let snapshot = try #require(CalorieCardSnapshotBuilder.build(sample: sample, settings: settings))
        #expect(snapshot.appearance.labelBackground != nil)
        let before = try pixels(SharedCalorieCard(snapshot: snapshot, mode: .now), scheme: .dark, size: .large)
        settings.showCalorieLabelBackgrounds = false
        settings.calorieLabelBackground = .black
        let after = try pixels(SharedCalorieCard(snapshot: snapshot, mode: .now), scheme: .dark, size: .large)
        #expect(before == after)
    }

    @MainActor @Test
    func viewerIconsOnlyChangeRenderingAndNeverPublicationValues() throws {
        let settings = Settings.shared
        let original = settings.hideCalorieStatusIcons
        defer { settings.hideCalorieStatusIcons = original }
        let now = date("2026-11-06T12:00:00Z")
        var sample = HealthData.example(for: now)
        sample.lastDataSync = now
        settings.hideCalorieStatusIcons = false
        let visible = try #require(CalorieCardSnapshotBuilder.build(sample: sample, settings: settings))
        settings.hideCalorieStatusIcons = true
        let hidden = try #require(CalorieCardSnapshotBuilder.build(sample: sample, settings: settings))
        #expect(visible.now == hidden.now && visible.midnight == hidden.midnight)
        #expect(hidden.now.visibleGoalReached != nil)
        let renderedHidden = try pixels(SharedCalorieCard(hidesGoalStatus: true, snapshot: visible, mode: .now),
                                        scheme: .dark, size: .large)
        let noPermission = try pixels(SharedCalorieCard(snapshot: visible.withoutGoalInformation(), mode: .now),
                                     scheme: .dark, size: .large)
        let renderedVisible = try pixels(SharedCalorieCard(snapshot: visible, mode: .now), scheme: .dark, size: .large)
        #expect(renderedHidden == noPermission)
        #expect(renderedHidden != renderedVisible)
        let grant = SharingGrant(scope: .today, generation: UUID())
        let wire = visible.payload(for: .goals, calorieGrant: grant)
        let encoded = try JSONEncoder().encode(wire)
        let json = try #require(String(data: encoded, encoding: .utf8))
        #expect(wire.goalResult?.now == visible.now.visibleGoalReached)
        #expect(wire.now.energy.isEmpty && wire.midnight == nil)
        for forbidden in ["balanceGoal", "weightGoal", "goalTarget"] { #expect(!json.contains(forbidden)) }
        #expect(try JSONDecoder().decode(CalorieCardSnapshot.self, from: encoded) == wire)
    }

    /// Builds a snapshot using the test appearance and optional sender calendar.
    private func build(
        _ sample: HealthData,
        calendar: Calendar? = nil
    ) -> CalorieCardSnapshot? {
        CalorieCardSnapshotBuilder.build(
            sample: sample,
            policy: HealthSnapshotPolicy(),
            appearance: appearance,
            calendar: calendar ?? self.calendar("Europe/Zurich")
        )
    }

    /// Returns the adaptive colors shared by local and remote card rendering.
    private var appearance: CalorieCardSnapshot.Appearance {

        let color = CalorieCardSnapshot.AdaptiveColor(
            light: .init(red: 0.3, green: 0.4, blue: 0.5),
            dark: .init(red: 0.5, green: 0.6, blue: 0.7)
        )
        return .init(burned: color, consumed: color, cardBackground: color, graphEmpty: color)
    }

    /// Creates a Gregorian calendar for the given time zone.
    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    /// Parses an ISO 8601 date used by the fixed snapshot fixtures.
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    @MainActor
    /// Renders a card into pixels at a fixed width and appearance.
    private func pixels(_ view: some View, scheme: ColorScheme, size: DynamicTypeSize) throws -> [UInt8] {

        let renderer = ImageRenderer(
            content: view
                .environment(\.colorScheme, scheme)
                .environment(\.dynamicTypeSize, size)
                .transaction { $0.disablesAnimations = true }
                .frame(width: 360)
                .fixedSize(horizontal: false, vertical: true)
        )
        renderer.scale = 1
        let image = try #require(renderer.uiImage?.cgImage)
        var result = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let rendered = result.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        #expect(rendered)
        return result
    }

}
