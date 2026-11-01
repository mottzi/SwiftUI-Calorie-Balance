import CloudKit
import UIKit

/// Metadata invitation handoff and quiet CloudKit notification handler.
final class SharingAppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if DEBUG
        if NSClassFromString("XCTestCase") != nil { return true }
        #endif
        SharingRuntime.shared.prepareHealthObservationAtLaunch()
        return true
    }

    /// Configures scenes to receive CloudKit invitation handoffs.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SharingSceneDelegate.self
        return configuration
    }

    /// Imports metadata for a CloudKit share accepted by the user.
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in await SharingRuntime.shared.importInvitation(cloudKitShareMetadata) }
    }

    /// Refreshes sharing state after a recognized CloudKit notification.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else { completionHandler(.noData); return }
        Task { @MainActor in
            completionHandler(await SharingRuntime.shared.receiveRemoteChange())
        }
    }

}

/// Scene-level CloudKit invitation handoff handler.
final class SharingSceneDelegate: NSObject, UIWindowSceneDelegate {

    /// Imports share metadata provided while the scene connects.
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {

        if let metadata = connectionOptions.cloudKitShareMetadata {
            Task { @MainActor in await SharingRuntime.shared.importInvitation(metadata) }
        }
    }

    /// Imports metadata for a CloudKit share accepted in this scene.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in await SharingRuntime.shared.importInvitation(cloudKitShareMetadata) }
    }

}
