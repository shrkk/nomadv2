import SwiftUI

// OnboardingView — paged container for the 7-screen onboarding flow.
// D-01: Full-screen paged flow with progress dots and back navigation.
// D-02: Each screen fills the display; no nested sheet presentation.
// Transitions: horizontal slide with spring (damping 0.85, response 0.4).

struct OnboardingView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(UserService.self) private var userService

    @State private var coordinator = OnboardingCoordinator()
    @State private var isForward: Bool = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Current screen
            Group {
                switch coordinator.currentStep {
                case .welcome:
                    WelcomeScreen(coordinator: coordinator)
                case .signUp:
                    SignUpScreen(coordinator: coordinator)
                case .handle:
                    HandleScreen(coordinator: coordinator)
                case .locationPermission:
                    LocationPermissionScreen(coordinator: coordinator)
                case .photosPermission:
                    PhotosPermissionScreen(coordinator: coordinator)
                case .discoveryScope:
                    DiscoveryScopeScreen(coordinator: coordinator)
                case .homeCity:
                    HomeCityScreen(coordinator: coordinator)
                }
            }
            .transition(
                isForward
                    ? .asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading))
                    : .asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .trailing))
            )
            .animation(.spring(duration: 0.4, bounce: 0.15), value: coordinator.currentStep)
            .id(coordinator.currentStep)

            // Progress dots + back button overlay (screens 2–7)
            if coordinator.currentStep != .welcome {
                VStack(spacing: 0) {
                    // Progress dots
                    progressDots
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity)

                // Back chevron
                Button {
                    isForward = false
                    coordinator.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.Nomad.globeBackground.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
                .padding(.top, 8)
                .padding(.leading, 8)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onChange(of: coordinator.currentStep) { oldStep, newStep in
            isForward = newStep.rawValue > oldStep.rawValue
        }
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<coordinator.progressDotCount, id: \.self) { index in
                Circle()
                    .fill(index == coordinator.activeDotIndex
                          ? Color.Nomad.amber
                          : Color.Nomad.warmCard)
                    .frame(width: 8, height: 8)
            }
        }
    }
}
