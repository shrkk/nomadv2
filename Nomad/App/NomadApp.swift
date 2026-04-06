import SwiftUI
import SwiftData
import FirebaseCore

// NomadApp — root entry point.
// Auth-gated routing: loading -> silent wait, unauthenticated -> onboarding, authenticated -> globe.
// D-09: AuthManager and UserService injected as environment objects for all descendant views.
// D-11: .loading state renders silent background color to avoid flash of onboarding.
// Note: FirebaseApp.configure() must run before AuthManager() accesses Auth.auth(),
// so it is called in init() before @State backing stores are set.

@main
struct NomadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authManager: AuthManager
    @State private var userService: UserService

    init() {
        FirebaseApp.configure()
        _authManager = State(wrappedValue: AuthManager())
        _userService = State(wrappedValue: UserService())
    }

    var body: some Scene {
        WindowGroup {
            content
                .environment(authManager)
                .environment(userService)
                .modelContainer(for: [RoutePoint.self, TripLocal.self])
        }
    }

    @ViewBuilder
    private var content: some View {
        switch authManager.authState {
        case .loading:
            Color.Nomad.globeBackground
                .ignoresSafeArea()
        case .unauthenticated:
            OnboardingView()
        case .authenticated:
            GlobeView()
        }
    }
}
