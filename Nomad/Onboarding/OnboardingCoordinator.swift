import Observation

// OnboardingCoordinator — step state machine driving the onboarding flow.
// D-03: Step order: welcome → signUp → handle → locationPermission → photosPermission → healthPermission → discoveryScope → homeCity
// D-04: Handle text and validation state shared across screens.
// D-06: discoveryScope defaults to "awayOnly" per UI-SPEC (Card 2 pre-selected).
// D-07: Home city name and coordinates accumulated here for final Firestore write.

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case signUp
    case handle
    case locationPermission
    case photosPermission
    case healthPermission
    case discoveryScope
    case homeCity
}

@Observable @MainActor final class OnboardingCoordinator {
    var currentStep: OnboardingStep = .welcome

    // Sign-in mode toggle — SignUpScreen adapts header, CTA, and auth call based on this.
    var isSignInMode: Bool = false

    // Accumulated data across screens — committed to Firestore at HomeCity confirm.
    var email: String = ""
    var password: String = ""
    var handle: String = ""
    var discoveryScope: String = "awayOnly"    // D-06: away-only default
    var homeCityName: String = ""
    var homeCityLatitude: Double = 0
    var homeCityLongitude: Double = 0

    // MARK: - Navigation

    func advance() {
        let nextRaw = currentStep.rawValue + 1
        if let next = OnboardingStep(rawValue: nextRaw) {
            currentStep = next
        }
        // No-op if already at homeCity (last step) — NomadApp routes away on auth state change.
    }

    func goBack() {
        let prevRaw = currentStep.rawValue - 1
        if let prev = OnboardingStep(rawValue: prevRaw) {
            currentStep = prev
        }
        // Clamp: no-op if already at .welcome.
    }

    // MARK: - Progress dots

    /// Number of progress dots shown on screens 2–8.
    var progressDotCount: Int { 7 }

    /// 0-based dot index that should appear active. nil for the welcome screen.
    var activeDotIndex: Int? {
        switch currentStep {
        case .welcome: return nil
        case .signUp: return 0
        case .handle: return 1
        case .locationPermission: return 2
        case .photosPermission: return 3
        case .healthPermission: return 4
        case .discoveryScope: return 5
        case .homeCity: return 6
        }
    }
}
