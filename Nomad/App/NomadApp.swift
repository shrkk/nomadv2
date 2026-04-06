import SwiftUI
import SwiftData

// NomadApp — root entry point.
// Auth-gated routing: loading -> silent wait, unauthenticated -> onboarding, authenticated -> globe.
// D-09: AuthManager injected as environment object for all descendant views.
// D-11: .loading state renders silent background color to avoid flash of onboarding.

@main
struct NomadApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            content
                .environment(authManager)
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
            // Plan 02 builds OnboardingView — placeholder until then.
            Text("Onboarding Placeholder")
        case .authenticated:
            GlobeView()
        }
    }
}
