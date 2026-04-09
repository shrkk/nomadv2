import SwiftUI
import CoreLocation

// HomeCityScreen — Screen 7 (final) of the onboarding flow.
// D-07: Auto-detect via CLGeocoder reverse-geocode, confirm/edit flow.
// D-08: Register 50km CLCircularRegion geofence on confirm.
// D-15: Calls userService.updateUserOnboardingComplete to write final user doc fields.
// UI-SPEC Screen 7: cream background, detection spinner, confirmation card, "That's not right" edit.

struct HomeCityScreen: View {
    var coordinator: OnboardingCoordinator
    @Environment(AuthManager.self) private var authManager
    @Environment(UserService.self) private var userService

    @State private var detectedCity: String?
    @State private var detectedLatitude: Double = 0
    @State private var detectedLongitude: Double = 0
    @State private var isDetecting: Bool = true
    @State private var isEditing: Bool = false
    @State private var editedCityName: String = ""
    @State private var detectionFailed: Bool = false

    @State private var isSaving: Bool = false
    @State private var saveError: String?

    // CLLocationManager must persist for the duration of detection
    @State private var locationManager = CLLocationManager()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your home base")
                    .font(AppFont.title())
                    .foregroundColor(Color.Nomad.textPrimary)
                    .padding(.top, 32)

                Text("We've detected your home city. Confirm it's right so we know when you've set off on an adventure.")
                    .font(AppFont.body())
                    .foregroundColor(Color.Nomad.textSecondary)
                    .lineSpacing(8)
                    .padding(.top, 8)

                detectionContent
                    .padding(.top, 32)

                if let error = saveError {
                    Button {
                        Task { await saveAndFinish() }
                    } label: {
                        Text("Couldn't save. Tap to retry.")
                            .font(AppFont.caption())
                            .foregroundColor(Color.Nomad.destructive)
                    }
                    .padding(.top, 8)
                }

                if !isDetecting {
                    ctaButton
                        .padding(.top, 32)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Nomad.panelBlack.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task {
            await detectHomeCity()
        }
    }

    // MARK: - Detection content

    @ViewBuilder
    private var detectionContent: some View {
        if isDetecting {
            HStack {
                Spacer()
                ProgressView()
                    .tint(Color.Nomad.accent)
                    .scaleEffect(1.2)
                Spacer()
            }
            .padding(.vertical, 32)
        } else if detectionFailed || isEditing {
            editField
        } else {
            VStack(alignment: .leading, spacing: 12) {
                cityConfirmCard
                    .transition(.opacity.animation(.easeInOut(duration: 0.1)))

                Button {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isEditing = true
                    }
                } label: {
                    Text("That's not right")
                        .font(AppFont.caption())
                        .foregroundColor(Color.Nomad.accent)
                        .underline()
                }
            }
        }
    }

    private var cityConfirmCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(Color.Nomad.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(detectedCity ?? "")
                    .font(AppFont.subheading())
                    .foregroundColor(Color.Nomad.textPrimary)

                Text("Your home city")
                    .font(AppFont.caption())
                    .foregroundColor(Color.Nomad.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
        )
        .cornerRadius(12)
    }

    private var editField: some View {
        VStack(alignment: .leading, spacing: 4) {
            if detectionFailed {
                Text("Could not detect your city")
                    .font(AppFont.body())
                    .foregroundColor(Color.Nomad.textSecondary)
                    .padding(.bottom, 8)
            }

            TextField("City name", text: $editedCityName)
                .font(AppFont.body())
                .foregroundColor(Color.Nomad.textPrimary)
                .autocapitalization(.words)
                .keyboardType(.default)
                .frame(height: 48)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.35))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
                )
                .cornerRadius(12)
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.1)))
    }

    // MARK: - CTA

    private var ctaButton: some View {
        let ctaLabel: String
        if detectionFailed {
            ctaLabel = "Set home city manually"
        } else {
            ctaLabel = "Confirm home city"
        }

        let isEnabled: Bool
        if isEditing || detectionFailed {
            isEnabled = !editedCityName.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
        } else {
            isEnabled = detectedCity != nil && !isSaving
        }

        return Button {
            Task { await saveAndFinish() }
        } label: {
            ZStack {
                if isSaving {
                    ProgressView()
                        .tint(Color.Nomad.panelBlack)
                } else {
                    Text(ctaLabel)
                        .font(AppFont.buttonLabel())
                        .foregroundColor(Color.Nomad.panelBlack)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.Nomad.accent.opacity(isEnabled ? 1.0 : 0.3))
            .cornerRadius(12)
        }
        .disabled(!isEnabled)
    }

    // MARK: - Detection

    private func detectHomeCity() async {
        let status = locationManager.authorizationStatus

        // If location permission not granted, fail gracefully
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            await MainActor.run {
                isDetecting = false
                detectionFailed = true
            }
            return
        }

        // Use a dedicated location manager for the one-time fix so delegate lifetime is controlled.
        let oneShotManager = CLLocationManager()
        do {
            let location = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
                let delegate = OneTimeLocationDelegate(continuation: continuation)
                // Delegate holds strong ref to continuation; store on manager via objc runtime.
                // We keep delegate alive by storing it in the delegate itself (retained by manager).
                oneShotManager.delegate = delegate
                oneShotManager.desiredAccuracy = kCLLocationAccuracyKilometer
                oneShotManager.requestLocation()
            }

            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks.first
            let cityName = placemark?.locality ?? placemark?.administrativeArea ?? placemark?.country

            await MainActor.run {
                if let city = cityName {
                    detectedCity = city
                    detectedLatitude = location.coordinate.latitude
                    detectedLongitude = location.coordinate.longitude
                    isDetecting = false
                } else {
                    isDetecting = false
                    detectionFailed = true
                }
            }
        } catch {
            await MainActor.run {
                isDetecting = false
                detectionFailed = true
            }
        }
    }

    // MARK: - Save

    private func saveAndFinish() async {
        guard case .authenticated(let user) = authManager.authState else { return }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        // Determine final city name and coordinates
        let finalCity: String
        let finalLat: Double
        let finalLon: Double

        if isEditing || detectionFailed {
            finalCity = editedCityName.trimmingCharacters(in: .whitespaces)
            finalLat = 0
            finalLon = 0
        } else {
            finalCity = detectedCity ?? ""
            finalLat = detectedLatitude
            finalLon = detectedLongitude
        }

        // D-08: Register 50km geofence if we have valid coordinates
        if finalLat != 0 || finalLon != 0 {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: finalLat, longitude: finalLon),
                radius: 50_000,
                identifier: "homeCityGeofence"
            )
            region.notifyOnEntry = false
            region.notifyOnExit = true
            CLLocationManager().startMonitoring(for: region)
        }

        do {
            try await userService.updateUserOnboardingComplete(
                uid: user.uid,
                homeCityName: finalCity,
                homeCityLatitude: finalLat,
                homeCityLongitude: finalLon,
                discoveryScope: coordinator.discoveryScope,
                geofenceRadius: 50_000
            )
            // Mark onboarding complete — updates AuthManager.onboardingComplete + UserDefaults,
            // which causes NomadApp to route to GlobeView.
            authManager.markOnboardingComplete()
        } catch {
            saveError = "Couldn't save. Tap to retry."
        }
    }
}

// MARK: - One-time location delegate

private final class OneTimeLocationDelegate: NSObject, CLLocationManagerDelegate {
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var didDeliver = false
    // Strong self-reference keeps this delegate alive until delivery,
    // since CLLocationManager.delegate is weak.
    private var selfRetain: OneTimeLocationDelegate?

    init(continuation: CheckedContinuation<CLLocation, Error>) {
        self.continuation = continuation
        super.init()
        selfRetain = self
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !didDeliver, let location = locations.first else { return }
        didDeliver = true
        continuation?.resume(returning: location)
        continuation = nil
        selfRetain = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !didDeliver else { return }
        didDeliver = true
        continuation?.resume(throwing: error)
        continuation = nil
        selfRetain = nil
    }
}
