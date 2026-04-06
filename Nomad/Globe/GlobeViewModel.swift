import SwiftUI
import Observation

// MARK: - GlobeViewModel
//
// Manages globe state: loads GeoJSON countries for overlay/tap interactions.
// Globe rendering handled by SceneKit in GlobeSceneView.

@Observable
@MainActor
class GlobeViewModel {
    var countries: [CountryFeature] = []
    var isLoading = true
    var error: String?

    // Country focus state
    var focusedCountryCode: String? = nil
    var showPinpoints = false
    var selectedTrip: GlobePinpoint.StubTrip? = nil
    var showProfileSheet = false

    // Stub trips grouped by country for pinpoint display
    var tripsByCountry: [String: [GlobePinpoint.StubTrip]] {
        Dictionary(grouping: GlobePinpoint.StubTrip.stubTrips, by: \.countryCode)
    }

    func animateToCountry(code: String) {
        focusedCountryCode = code
        showPinpoints = true

        // Find trip for this country to show profile sheet
        if let trip = GlobePinpoint.StubTrip.stubTrips.first(where: { $0.countryCode == code }) {
            selectedTrip = trip
            showProfileSheet = true
        }
    }

    func loadGlobeData() async {
        do {
            let parser = GeoJSONParser()
            let loaded = try await parser.loadCountries()
            countries = loaded
            print("[Globe] Loaded \(loaded.count) countries")
            isLoading = false
        } catch {
            print("[Globe] ERROR: \(error)")
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}
