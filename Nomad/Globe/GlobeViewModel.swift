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
