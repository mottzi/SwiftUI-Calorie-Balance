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

    private(set) var revision: String

    private init() {
        usesSampleData = Self.isSampleDataEnabled
        revision = Self.currentRevision
    }

    /// Also used after simulator seeding so cached empty results do not survive a save.
    func invalidateData() {
        #if DEBUG && (os(iOS) || os(watchOS))
        revision = UUID().uuidString
        Self.defaults.set(["enabled": usesSampleData, "revision": revision], forKey: Self.key)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Arguments are optional shortcuts; the Debug card remains the primary control.
    func configureLaunchArguments() {
        #if DEBUG && os(iOS)
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--health-data-sample") { usesSampleData = true }
        else if arguments.contains("--health-data-live") || arguments.contains("--health-data-seed-simulator") {
            usesSampleData = false
        }
        #endif
    }

}

extension HealthDataMode {

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

    static let shared = HealthDataMode()

}

extension HealthDataMode {

    private static let defaults = UserDefaults(suiteName: "group.4DXABR577J.com.count.kcal.app")!

    private static let key = "debugHealthDataMode"

}
