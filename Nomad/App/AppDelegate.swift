import UIKit
import FirebaseCore
import GoogleSignIn
import UserNotifications

// AppDelegate — Firebase initialization via UIApplicationDelegateAdaptor pattern.
// FirebaseApp.configure() must be called before any Firebase service is accessed.
// The app will not launch without GoogleService-Info.plist — see user_setup in PLAN.md.
// Source: INFRA-03 (REQUIREMENTS.md), 01-RESEARCH.md §Standard Stack Firebase 12.11.0.
//
// TRIP-03: Also conforms to UNUserNotificationCenterDelegate to count dismissed
// trip prompt notifications. After 3 dismissals, sets manualOnlyMode=true so
// VisitMonitor.handleGeofenceExit() stops sending auto-detect notifications.
//
// @preconcurrency suppresses Swift 6 actor-isolation crossing warning: UIApplicationDelegate
// is @MainActor-isolated, UNUserNotificationCenterDelegate callbacks arrive off-main.
// The delegate methods only touch UserDefaults (thread-safe) so this is safe.
class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // FirebaseApp.configure() is called in NomadApp.init() before AuthManager is created
        // Set self as notification delegate for trip prompt dismiss counting (TRIP-03)
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification responses — counts dismiss actions for TRIP-03.
    /// UNNotificationDismissActionIdentifier fires when user swipes away the notification,
    /// but only when the notification's category has .customDismissAction option
    /// (set in VisitMonitor.registerNotificationCategory).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier

        // Only count dismissals of trip prompt notifications (prefix "tripStartPrompt-")
        if identifier.hasPrefix("tripStartPrompt-") {
            let actionID = response.actionIdentifier

            if actionID == UNNotificationDismissActionIdentifier {
                // D-09: Increment dismiss counter and check threshold
                let count = UserDefaults.standard.integer(forKey: "tripPromptDismissCount") + 1
                UserDefaults.standard.set(count, forKey: "tripPromptDismissCount")

                if count >= 3 {
                    // TRIP-03: Switch to manual-only mode after 3 dismissed prompts
                    // VisitMonitor.handleGeofenceExit() checks this flag before sending notifications
                    UserDefaults.standard.set(true, forKey: "manualOnlyMode")
                }
            }
        }

        completionHandler()
    }

    /// Show notifications as banners + sound when app is in foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
