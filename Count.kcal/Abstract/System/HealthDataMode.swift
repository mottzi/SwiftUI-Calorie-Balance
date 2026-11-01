import Foundation
import Observation
import WidgetKit

/// Debug mode shared locally by apps and extensions, and sent from phone to watch.
@MainActor
@Observable
final class HealthDataMode {

    var usesSampleData: Bool {
        didSet {
            guard usesSampleData != oldValue else { return }
            invalidateData()
        }
    }

    var usesMarketingData: Bool {
        didSet {
            guard usesMarketingData != oldValue else { return }
            invalidateData()
        }
    }

    #if DEBUG && (os(iOS) || os(watchOS))
    var sampleProfile: SampleHealthProfile {
        didSet {
            guard sampleProfile != oldValue else { return }
            invalidateData()
        }
    }
    #endif

    private(set) var revision: String
    @ObservationIgnored private let storage: UserDefaults

    init(defaults: UserDefaults) {
        storage = defaults
        let saved = defaults.dictionary(forKey: Self.key)
        #if DEBUG && (os(iOS) || os(watchOS))
        usesSampleData = saved?["enabled"] as? Bool ?? false
        usesMarketingData = saved?["marketing"] as? Bool ?? false
        sampleProfile = (saved?["profile"] as? String).flatMap(SampleHealthProfile.init(rawValue:)) ?? .active
        revision = saved?["revision"] as? String ?? "healthkit"
        #else
        usesSampleData = false
        usesMarketingData = false
        revision = "healthkit"
        #endif
    }

    /// Also used after simulator seeding so cached empty results do not survive a save.
    func invalidateData() {
        #if DEBUG && (os(iOS) || os(watchOS))
        revision = UUID().uuidString
        storage.set([
            "enabled": usesSampleData, "marketing": usesMarketingData,
            "profile": sampleProfile.rawValue, "revision": revision
        ], forKey: Self.key)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Arguments are optional shortcuts; the Debug card remains the primary control.
    func configureLaunchArguments() {
        #if DEBUG && os(iOS)
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--health-data-marketing") {
            usesSampleData = true
            usesMarketingData = true
        } else if arguments.contains("--health-data-sample") {
            usesSampleData = true
        } else if arguments.contains("--health-data-live") || arguments.contains("--health-data-seed-simulator") {
            usesSampleData = false
        }
        #endif
    }

}

extension HealthDataMode {

    #if DEBUG && (os(iOS) || os(watchOS))
    static var currentSampleProfile: SampleHealthProfile {
        let rawValue = defaults.dictionary(forKey: key)?["profile"] as? String
        return rawValue.flatMap(SampleHealthProfile.init(rawValue:)) ?? .active
    }
    #endif

    static var isMarketingDataEnabled: Bool {
        #if DEBUG && (os(iOS) || os(watchOS))
        return isSampleDataEnabled && defaults.dictionary(forKey: key)?["marketing"] as? Bool == true
        #else
        return false
        #endif
    }

    /// Read defaults for every request so extensions see the latest local mode.
    static var isSampleDataEnabled: Bool {
        #if DEBUG && (os(iOS) || os(watchOS))
        return defaults.dictionary(forKey: key)?["enabled"] as? Bool ?? false
        #else
        return false
        #endif
    }

    static var currentRevision: String {
        #if DEBUG && (os(iOS) || os(watchOS))
        return defaults.dictionary(forKey: key)?["revision"] as? String ?? "healthkit"
        #else
        return "healthkit"
        #endif
    }

}

extension HealthDataMode {

    static let shared = HealthDataMode(defaults: defaults)

}

extension HealthDataMode {

    private static let defaults = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")!

    private static let key = "debugHealthDataMode"

}
