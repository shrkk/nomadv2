import SwiftUI
import Observation
import FirebaseAuth

// MARK: - GlobeViewModel
//
// Manages globe state: loads GeoJSON countries for overlay/tap interactions,
// and fetches real trip + visitedCountryCodes data from Firestore.
// T-03-01: All Firestore reads scoped to Auth.auth().currentUser?.uid.

@Observable
@MainActor
class GlobeViewModel {
    var countries: [CountryFeature] = []
    var isLoading = true
    var error: String?

    // Country focus state
    var focusedCountryCode: String? = nil
    var showPinpoints = false
    var selectedTrip: TripDocument? = nil
    var showProfileSheet = false

    // Country detail sheet state (03.1-04)
    var showCountryDetail = false
    var selectedCountryCode: String? = nil

    // Live Firestore data
    var trips: [TripDocument] = []
    var visitedCountryCodes: [String] = []
    var scrollToTripId: String? = nil
    var selectedInitialCity: String? = nil

    // MARK: - Country Detail Sheet

    /// Present CountryDetailSheet for the tapped country.
    /// T-3.1-09: Dismiss ProfileSheet first — only one sheet at a time.
    func showCountryDetailSheet(code: String) {
        showProfileSheet = false
        selectedCountryCode = code
        focusedCountryCode = code
        showPinpoints = true
        showCountryDetail = true
    }

    func animateToCountry(code: String) {
        showCountryDetailSheet(code: code)
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

        // T-03-01: Only fetch if user is authenticated — scoped to current user's UID.
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[Globe] No authenticated user — skipping Firestore fetch")
            return
        }
        let tripService = TripService()
        if let fetched = try? await tripService.fetchTrips(userId: uid) {
            trips = fetched
            print("[Globe] Loaded \(fetched.count) trips from Firestore")
        }
        if let codes = try? await tripService.fetchVisitedCountryCodes(userId: uid) {
            visitedCountryCodes = codes
            print("[Globe] Loaded \(codes.count) visited country codes")
        }
    }
}
