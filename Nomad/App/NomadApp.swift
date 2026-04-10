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
    @State private var locationManager = LocationManager()
    // Coordinator lives here so its step position survives auth state changes mid-onboarding.
    @State private var onboardingCoordinator = OnboardingCoordinator()

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
                .environment(locationManager)
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
            OnboardingView(coordinator: onboardingCoordinator)
        case .authenticated:
            if authManager.onboardingComplete {
                GlobeView()
            } else {
                // Authenticated but onboarding not finished (e.g. Google sign-in mid-flow,
                // or returning user on new device). Skip past welcome/signUp since auth
                // is already established — avoids re-prompting for login on every launch.
                OnboardingView(coordinator: onboardingCoordinator)
                    .onAppear {
                        if onboardingCoordinator.currentStep == .welcome
                            || onboardingCoordinator.currentStep == .signUp {
                            onboardingCoordinator.currentStep = .handle
                        }
                    }
            }
        }
    }
}
