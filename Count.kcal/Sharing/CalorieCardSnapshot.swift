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
    let now: ModeValues

    /// Projected values for the end of the day, if still valid at capture time.
    let midnight: ModeValues?

    /// Unit used for every energy value.
    let energyUnit: EnergyUnit

    /// Sender colors needed to reproduce the card.
    let appearance: Appearance

    /// Sender exclusion used by the shared week, absent in older snapshots.
    var isExcluded: Bool?

    /// Optional full streak, published only through a separately accepted Streak scope.
    var streak: StreakSummary? = nil

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

        /// Goal result, or `nil` if the sender hides goal status.
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

        /// Checks each color for both appearances.
        var isValid: Bool {
            burned.isValid && consumed.isValid && cardBackground.isValid && graphEmpty.isValid
                && (labelBackground?.isValid ?? true)
                && (pageBackground?.isValid ?? true)
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

    /// Keeps streaks out of calorie grants and calories out of streak grants.
    func payload(for scope: SharingScope) -> Self {
        var result = self
        guard scope == .streaks else {
            result.streak = nil
            return result
        }
        result = Self(
            id: id, senderLocalDate: senderLocalDate, timeZoneIdentifier: timeZoneIdentifier,
            dayStart: dayStart, dayEnd: dayEnd, capturedAt: capturedAt,
            now: .init(energy: EnergyBalance(active: 0, resting: 0, restingRemaining: 0, consumed: 0),
                       visibleGoalReached: nil),
            midnight: nil, energyUnit: energyUnit, appearance: appearance
        )
        result.streak = streak
        return result
    }

    /// Formats a date with the supplied calendar's time zone.
    static func localDate(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

}
