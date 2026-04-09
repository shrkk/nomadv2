import SwiftUI
import CoreLocation

// LocationPermissionScreen — Screen 4 of the onboarding flow.
// D-05: Pre-prompt explanation before native iOS dialog fires.
// Two-step authorization: requestWhenInUseAuthorization → requestAlwaysAuthorization.
// Onboarding never blocks on denial — always advance after any dialog result.
// UI-SPEC Screen 4: cream background, location.fill icon, amber CTA.

/// Helper class to manage CLLocationManager delegate callbacks.
/// @Observable + NSObject for SwiftUI + CoreLocation compatibility.
@Observable
final class LocationPermissionRequester: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var didReceiveResult: Bool = false

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestPermission() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            // Already determined — treat as "done"
            didReceiveResult = true
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedWhenInUse:
            // Step 2: escalate to Always (per RESEARCH.md Pitfall 5 — two-step)
            manager.requestAlwaysAuthorization()
        case .notDetermined:
            break // Still waiting for first dialog
        default:
            // authorizedAlways, denied, restricted — dialog closed, advance
            didReceiveResult = true
        }
    }
}

struct LocationPermissionScreen: View {
    var coordinator: OnboardingCoordinator

    @State private var requester = LocationPermissionRequester()
    @State private var isRequesting: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "location.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color.Nomad.textPrimary)

                Text("Keep your journey alive")
                    .font(AppFont.title())
                    .foregroundColor(Color.Nomad.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Nomad tracks your route in the background, even when your phone is locked. This is what paints your path on the globe.")
                    .font(AppFont.body())
                    .foregroundColor(Color.Nomad.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8) // 1.5 line height approximation
            }
            .padding(.horizontal, 16)

            Spacer()

            Button {
                isRequesting = true
                requester.requestPermission()
            } label: {
                Text("Enable background location")
                    .font(AppFont.buttonLabel())
                    .foregroundColor(Color.Nomad.panelBlack)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.Nomad.accent)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Nomad.panelBlack.ignoresSafeArea())
        .onChange(of: requester.didReceiveResult) { _, received in
            if received {
                coordinator.advance()
            }
        }
    }
}
