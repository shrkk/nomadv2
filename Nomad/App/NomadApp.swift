import SwiftUI
import SwiftData

// NomadApp — root entry point.
// Auth-gated routing: loading -> silent wait, unauthenticated -> onboarding, authenticated -> globe.
// D-09: AuthManager and UserService injected as environment objects for all descendant views.
// D-11: .loading state renders silent background color to avoid flash of onboarding.

@main
struct NomadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authManager = AuthManager()
    @State private var userService = UserService()

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
