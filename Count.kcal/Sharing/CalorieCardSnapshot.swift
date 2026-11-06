import Foundation

/// Immutable values needed to render one sender's calorie card.
struct CalorieCardSnapshot: Codable, Equatable, Sendable, Identifiable {
    /// Snapshot identifier used by its shared record.
    let id: UUID

    /// Format version used to reject snapshots this app cannot read.
    let schemaVersion: Int

    /// Sender-local date label for this snapshot.
    let senderLocalDate: String

    /// Time zone used to define the sender's local day.
    let timeZoneIdentifier: String

    /// Start of the sender's local day.
    let dayStart: Date

    /// Start of the next sender-local day.
    let dayEnd: Date

    /// Time when the sender captured these values.
    let capturedAt: Date

    /// Recorded values at capture time.
    var now: ModeValues

    /// Projected values for the end of the day, if still valid at capture time.
    var midnight: ModeValues?

    /// Unit used for every energy value.
    let energyUnit: EnergyUnit

    /// Sender colors needed to reproduce the card.
    var appearance: Appearance

    /// Sender exclusion used by the shared week, absent in older snapshots.
    var isExcluded: Bool?

    /// Optional full streak, published only through the Goal status & streak scope.
    var streak: StreakSummary? = nil

    /// Goal results travel only under the separately accepted goal scope.
    var goalResult: GoalResult? = nil

    init(
        id: UUID = UUID(),
        schemaVersion: Int = Self.currentSchemaVersion,
        senderLocalDate: String,
        timeZoneIdentifier: String,
        dayStart: Date,
        dayEnd: Date,
        capturedAt: Date,
        now: ModeValues,
        midnight: ModeValues?,
        energyUnit: EnergyUnit,
        appearance: Appearance,
        isExcluded: Bool? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.senderLocalDate = senderLocalDate
        self.timeZoneIdentifier = timeZoneIdentifier
        self.dayStart = dayStart
        self.dayEnd = dayEnd
        self.capturedAt = capturedAt
        self.now = now
        self.midnight = midnight
        self.energyUnit = energyUnit
        self.appearance = appearance
        self.isExcluded = isExcluded
    }

    /// Reject unknown versions and malformed remote values before rendering or caching.
    var isSupported: Bool {
        guard schemaVersion == Self.currentSchemaVersion,
              let zone = TimeZone(identifier: timeZoneIdentifier),
              dayStart.timeIntervalSinceReferenceDate.isFinite,
              dayEnd.timeIntervalSinceReferenceDate.isFinite,
              capturedAt.timeIntervalSinceReferenceDate.isFinite,
              dayStart < dayEnd, capturedAt >= dayStart,
              now.isValid, now.restingRemaining == 0,
              midnight?.isValid ?? true,
              streak?.isValid ?? true,
              goalResult?.isValid ?? true,
              appearance.isValid else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        guard calendar.startOfDay(for: dayStart) == dayStart,
              calendar.date(byAdding: .day, value: 1, to: dayStart) == dayEnd,
              Self.localDate(for: dayStart, calendar: calendar) == senderLocalDate else { return false }
        // projection belongs only to the sender's current day at capture time
        return midnight == nil || capturedAt < dayEnd
    }

    /// Unit used by the sender's energy values.
    enum EnergyUnit: String, Codable, Sendable {

        /// Kilocalories.
        case kcal

        /// Kilojoules.
        case kJ

    }

    /// Energy values and the goal result for one card mode.
    struct ModeValues: Codable, Equatable, Sendable {
        /// Recorded active energy.
        let active: Int

        /// Recorded resting energy.
        let resting: Int

        /// Projected resting energy after the last sample.
        let restingRemaining: Int

        /// Recorded consumed energy.
        let consumed: Int

        /// Total recorded and projected energy burned.
        let burned: Int

        /// Burned energy minus consumed energy.
        let balance: Int

        /// Local goal result, or a separately permitted received result.
        let visibleGoalReached: Bool?

        init(energy: EnergyBalance, visibleGoalReached: Bool?) {
            active = energy.active
            resting = energy.resting
            restingRemaining = energy.restingRemaining
            consumed = energy.consumed
            burned = energy.burned
            balance = energy.balance
            self.visibleGoalReached = visibleGoalReached
        }

        /// Rebuilds the local energy value from its portable components.
        var energy: EnergyBalance {
            EnergyBalance(active: active, resting: resting, restingRemaining: restingRemaining, consumed: consumed)
        }

        /// Checks component bounds and total consistency before rendering.
        var isValid: Bool {
            let components = [active, resting, restingRemaining, consumed]
            guard components.allSatisfy({ (0...100_000_000).contains($0) }) else { return false }
            return burned == active + resting + restingRemaining && balance == burned - consumed
                && (burned != 0 || consumed != 0 || visibleGoalReached == nil)
        }
    }

    /// Portable extended sRGB color components.
    struct RGBA: Codable, Equatable, Sendable {
        /// Red component.
        let red: Double

        /// Green component.
        let green: Double

        /// Blue component.
        let blue: Double

        /// Alpha component.
        let opacity: Double

        init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.opacity = opacity
        }

        /// Checks that color components are finite and within accepted bounds.
        var isValid: Bool {
            [red, green, blue].allSatisfy { $0.isFinite && (-16...16).contains($0) }
                && opacity.isFinite && (0...1).contains(opacity)
        }
    }

    /// Light and dark color variants.
    struct AdaptiveColor: Codable, Equatable, Sendable {
        /// Color for a light appearance.
        let light: RGBA

        /// Color for a dark appearance.
        let dark: RGBA

        /// Checks both appearance variants.
        var isValid: Bool { light.isValid && dark.isValid }
    }

    /// Sender colors used by the native card presentation.
    struct Appearance: Codable, Equatable, Sendable {
        /// Color for burned energy.
        let burned: AdaptiveColor

        /// Color for consumed energy.
        let consumed: AdaptiveColor

        /// Card background color.
        let cardBackground: AdaptiveColor

        /// Color for empty graph space.
        let graphEmpty: AdaptiveColor

        /// Optional label fill; older snapshots use plain labels.
        var labelBackground: AdaptiveColor? = nil

        /// Full detail-page background; absent in snapshots from older senders.
        var pageBackground: AdaptiveColor? = nil

        /// Sender's goal accent for their name, independent of Streak permission.
        var nameColor: AdaptiveColor? = nil

        /// Older senders used the burned-energy color for names.
        var resolvedNameColor: AdaptiveColor { nameColor ?? burned }

        /// Checks each color for both appearances.
        var isValid: Bool {
            burned.isValid && consumed.isValid && cardBackground.isValid && graphEmpty.isValid
                && (labelBackground?.isValid ?? true)
                && (pageBackground?.isValid ?? true)
                && (nameColor?.isValid ?? true)
        }
    }

    /// Schema version supported by this app.
    static let currentSchemaVersion = 1
}

extension CalorieCardSnapshot {

    struct StreakSummary: Codable, Equatable, Sendable {
        let days: Int
        let color: AdaptiveColor

        var isValid: Bool { (0...200).contains(days) && color.isValid }
    }

    /// The calorie grant binds each goal result to the same permitted date range.
    struct GoalResult: Codable, Equatable, Sendable {
        let calorieScope: SharingScope
        let calorieGeneration: UUID
        let now: Bool?
        let midnight: Bool?
        let isExcluded: Bool?

        var isValid: Bool {
            (calorieScope == .today || calorieScope == .history)
                && (calorieScope != .history || midnight == nil)
        }
    }

    /// Calorie permissions never carry goal information, regardless of sender encoding.
    func withoutGoalInformation() -> Self {
        var result = self
        result.now = .init(energy: now.energy, visibleGoalReached: nil)
        result.midnight = midnight.map { .init(energy: $0.energy, visibleGoalReached: nil) }
        result.streak = nil
        result.goalResult = nil
        result.isExcluded = nil
        return result
    }

    /// Scope-specific wire payload, with no numeric goal target in any scope.
    func payload(for scope: SharingScope, calorieGrant: SharingGrant? = nil) -> Self {
        if scope == .today || scope == .history { return withoutGoalInformation() }
        var result = Self(
            id: id, senderLocalDate: senderLocalDate, timeZoneIdentifier: timeZoneIdentifier,
            dayStart: dayStart, dayEnd: dayEnd, capturedAt: capturedAt,
            now: .init(energy: EnergyBalance(active: 0, resting: 0, consumed: 0), visibleGoalReached: nil),
            midnight: nil, energyUnit: energyUnit, appearance: appearance
        )
        result.streak = streak
        if scope == .goals, let calorieGrant {
            result.goalResult = .init(calorieScope: calorieGrant.scope,
                calorieGeneration: calorieGrant.generation, now: now.visibleGoalReached,
                midnight: calorieGrant.scope == .today ? midnight?.visibleGoalReached : nil,
                isExcluded: isExcluded)
        }
        return result
    }

    /// Adds only separately permitted goal results to an already sanitized calorie card.
    func displayingGoalInformation(from goal: Self) -> Self {
        var result = self
        if let status = goal.goalResult, goal.id == id, goal.capturedAt == capturedAt {
            result.now = .init(energy: now.energy, visibleGoalReached: status.now)
            result.midnight = midnight.map { .init(energy: $0.energy, visibleGoalReached: status.midnight) }
            result.isExcluded = status.isExcluded
        }
        return result
    }

    /// Formats a date with the supplied calendar's time zone.
    static func localDate(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

}
