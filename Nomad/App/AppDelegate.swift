import UIKit
import FirebaseCore

// AppDelegate — Firebase initialization via UIApplicationDelegateAdaptor pattern.
// FirebaseApp.configure() must be called before any Firebase service is accessed.
// The app will not launch without GoogleService-Info.plist — see user_setup in PLAN.md.
// Source: INFRA-03 (REQUIREMENTS.md), 01-RESEARCH.md §Standard Stack Firebase 12.11.0.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
