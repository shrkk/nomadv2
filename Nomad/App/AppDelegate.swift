import UIKit

// AppDelegate — Firebase is initialized here via FirebaseApp.configure().
// NOTE: FirebaseCore import and initialization are added in Task 2 once
// Firebase SPM packages are resolved. This stub compiles without Firebase.
// The app will crash on launch without GoogleService-Info.plist —
// this is expected and documented in the threat model.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Firebase initialization added in Task 2
        return true
    }
}
