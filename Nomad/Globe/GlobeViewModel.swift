import SwiftUI
import RealityKit
import Observation

// MARK: - GlobeViewModel
//
// Manages globe state: loads GeoJSON countries, prepares overlay texture,
// and tracks rotation/zoom state driven by gestures in GlobeView.
//
// @MainActor isolation ensures @Observable mutations happen on the main actor,
// satisfying Swift 6 strict concurrency requirements.

@Observable
@MainActor
class GlobeViewModel {
    var countries: [CountryFeature] = []
    var overlayTexture: TextureResource?
    var isLoading = true
    var error: String?

    // Globe rotation state (controlled by gestures in GlobeView)
    var rotationX: Float = 0  // pitch
    var rotationY: Float = 0  // yaw
    var cameraDistance: Float = 2.0  // default camera distance from origin

    // Minimum and maximum zoom distances
    let minCameraDistance: Float = 0.8   // continent-level zoom
    let maxCameraDistance: Float = 2.5   // full globe view

    // Country focus state — driven by tap-to-animate interaction (GLOBE-03)
    var focusedCountryCode: String? = nil
    var showPinpoints = false
    var selectedTrip: GlobePinpoint.StubTrip? = nil
    var showProfileSheet = false

    // Stub trips grouped by country for pinpoint display
    var tripsByCountry: [String: [GlobePinpoint.StubTrip]] {
        Dictionary(grouping: GlobePinpoint.StubTrip.stubTrips, by: \.countryCode)
    }

    /// Animates globe rotation to bring the target country's centroid to camera-facing position.
    /// Duration: 600ms ease-in-out per UI-SPEC Interaction Contract.
    func animateToCountry(code: String) {
        guard let country = countries.first(where: { $0.isoCode == code }) else { return }

        // Compute centroid from first polygon's coordinates
        let coords = country.polygons.first ?? []
        guard !coords.isEmpty else { return }
        let avgLat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let avgLon = coords.map(\.longitude).reduce(0, +) / Double(coords.count)

        // Target rotation to bring centroid to front of camera
        let targetYaw = Float(-avgLon * .pi / 180)
        let targetPitch = Float(-avgLat * .pi / 180)

        withAnimation(.easeInOut(duration: 0.6)) {
            rotationY = targetYaw
            rotationX = targetPitch
            cameraDistance = 1.2  // zoom to region level
        }

        focusedCountryCode = code
        showPinpoints = true
    }

    func loadGlobeData() async {
        do {
            let parser = GeoJSONParser()
            let loaded = try await parser.loadCountries()
            countries = loaded

            // Render overlay texture off main thread (heavy CoreGraphics work)
            let overlayImage = await Task.detached(priority: .userInitiated) {
                GlobeCountryOverlay.renderOverlayTexture(countries: loaded)
            }.value

            // makeTextureResource is @MainActor — already on main actor here
            let texture = try GlobeCountryOverlay.makeTextureResource(from: overlayImage)
            overlayTexture = texture
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}
