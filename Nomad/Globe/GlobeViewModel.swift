import SwiftUI
import Observation
import CoreLocation
import Photos
@preconcurrency import FirebaseAuth

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

    // Home city pin
    var homeCityName: String? = nil
    var homeCityCoordinate: CLLocationCoordinate2D? = nil

    // Trip pin photos (keyed by trip ID)
    var tripPhotos: [String: UIImage] = [:]

    // Active route overlay (drawn on globe when zoomed into a trip)
    var activeRouteCoordinates: [CLLocationCoordinate2D] = []

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

    /// Fetch full route points for a trip and set them as the active overlay.
    func loadRouteOverlay(for trip: TripDocument) async {
        // TEST: hardcoded route for the Seattle test trip
        if trip.id == "test-seattle-walk" {
            activeRouteCoordinates = Self.testSeattleRoute
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let tripService = TripService()
        if let coords = try? await tripService.fetchRouteCoordinates(userId: uid, tripId: trip.id) {
            activeRouteCoordinates = coords
        }
    }

    /// Clear the active route overlay.
    func clearRouteOverlay() {
        activeRouteCoordinates = []
    }

    /// Delete a trip from Firestore and remove it from local state.
    func deleteTrip(_ trip: TripDocument) {
        trips.removeAll { $0.id == trip.id }
        tripPhotos.removeValue(forKey: trip.id)

        Task {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            let tripService = TripService()
            try? await tripService.deleteTrip(userId: uid, tripId: trip.id)
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

        // Fetch home city for globe pin
        let userService = UserService()
        if let userData = try? await userService.fetchUserDocument(uid: uid) {
            let name = userData[FirestoreSchema.UserFields.homeCityName] as? String
            let lat = userData[FirestoreSchema.UserFields.homeCityLatitude] as? Double
            let lon = userData[FirestoreSchema.UserFields.homeCityLongitude] as? Double
            if let name, let lat, let lon, lat != 0 || lon != 0 {
                homeCityName = name
                homeCityCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }

        // TEST: inject hardcoded Seattle walk trip for route visualization testing
        let testTrip = TripDocument(
            id: "test-seattle-walk",
            cityName: "Seattle",
            startDate: Date(timeIntervalSinceNow: -86400 * 3),
            endDate: Date(timeIntervalSinceNow: -86400 * 3 + 5400),
            stepCount: 4200,
            distanceMeters: 3100,
            routePreview: [[47.6145, -122.3424], [47.6386, -122.3372]],
            visitedCountryCodes: ["US"],
            placeCounts: ["culture": 1]
        )
        trips.append(testTrip)

        // Load random photo thumbnails for trip pins
        await loadTripPhotos()
    }

    // MARK: - Test Route Data (The Standard Apartments → Gates Foundation, Seattle)
    // Walking route following streets: north on Minor Ave, west on Pike, north through
    // Westlake/SLU, east on Mercer, north on 5th Ave N to the Gates Foundation.

    static let testSeattleRoute: [CLLocationCoordinate2D] = [
        // The Standard Apartments (First Hill, ~1120 8th Ave)
        CLLocationCoordinate2D(latitude: 47.6145, longitude: -122.3275),
        // North on Minor Ave
        CLLocationCoordinate2D(latitude: 47.6155, longitude: -122.3275),
        CLLocationCoordinate2D(latitude: 47.6165, longitude: -122.3275),
        CLLocationCoordinate2D(latitude: 47.6175, longitude: -122.3275),
        // West on Pike St
        CLLocationCoordinate2D(latitude: 47.6175, longitude: -122.3290),
        CLLocationCoordinate2D(latitude: 47.6175, longitude: -122.3310),
        CLLocationCoordinate2D(latitude: 47.6175, longitude: -122.3330),
        CLLocationCoordinate2D(latitude: 47.6175, longitude: -122.3350),
        // Convention center area, slight jog north
        CLLocationCoordinate2D(latitude: 47.6182, longitude: -122.3360),
        CLLocationCoordinate2D(latitude: 47.6190, longitude: -122.3365),
        // North on Westlake Ave
        CLLocationCoordinate2D(latitude: 47.6200, longitude: -122.3378),
        CLLocationCoordinate2D(latitude: 47.6210, longitude: -122.3385),
        CLLocationCoordinate2D(latitude: 47.6220, longitude: -122.3390),
        CLLocationCoordinate2D(latitude: 47.6230, longitude: -122.3395),
        CLLocationCoordinate2D(latitude: 47.6240, longitude: -122.3398),
        // Westlake through Denny Triangle
        CLLocationCoordinate2D(latitude: 47.6250, longitude: -122.3400),
        CLLocationCoordinate2D(latitude: 47.6258, longitude: -122.3402),
        CLLocationCoordinate2D(latitude: 47.6265, longitude: -122.3405),
        // South Lake Union — Westlake Ave N
        CLLocationCoordinate2D(latitude: 47.6275, longitude: -122.3407),
        CLLocationCoordinate2D(latitude: 47.6285, longitude: -122.3405),
        CLLocationCoordinate2D(latitude: 47.6295, longitude: -122.3400),
        CLLocationCoordinate2D(latitude: 47.6305, longitude: -122.3395),
        CLLocationCoordinate2D(latitude: 47.6315, longitude: -122.3390),
        // East on Mercer St
        CLLocationCoordinate2D(latitude: 47.6324, longitude: -122.3385),
        CLLocationCoordinate2D(latitude: 47.6324, longitude: -122.3370),
        CLLocationCoordinate2D(latitude: 47.6324, longitude: -122.3355),
        CLLocationCoordinate2D(latitude: 47.6324, longitude: -122.3340),
        // North on 5th Ave N
        CLLocationCoordinate2D(latitude: 47.6334, longitude: -122.3340),
        CLLocationCoordinate2D(latitude: 47.6344, longitude: -122.3340),
        CLLocationCoordinate2D(latitude: 47.6354, longitude: -122.3345),
        CLLocationCoordinate2D(latitude: 47.6362, longitude: -122.3350),
        // Approaching Gates Foundation campus
        CLLocationCoordinate2D(latitude: 47.6370, longitude: -122.3355),
        CLLocationCoordinate2D(latitude: 47.6378, longitude: -122.3362),
        // Bill & Melinda Gates Foundation
        CLLocationCoordinate2D(latitude: 47.6386, longitude: -122.3372),
    ]

    /// Fetch a random photo from the device gallery for each trip's date range.
    private func loadTripPhotos() async {
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authStatus == .authorized || authStatus == .limited else { return }

        for trip in trips {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                trip.startDate as CVarArg,
                trip.endDate as CVarArg
            )
            let result = PHAsset.fetchAssets(with: .image, options: options)
            guard result.count > 0 else { continue }

            // Pick a random asset
            let randomIndex = Int.random(in: 0..<result.count)
            let asset = result.object(at: randomIndex)

            let targetSize = CGSize(width: 120, height: 120)
            let image: UIImage? = await withCheckedContinuation { cont in
                let reqOptions = PHImageRequestOptions()
                reqOptions.deliveryMode = .highQualityFormat
                reqOptions.isSynchronous = false
                reqOptions.isNetworkAccessAllowed = true
                reqOptions.resizeMode = .exact

                var resumed = false
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: reqOptions
                ) { image, info in
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if !isDegraded && !resumed {
                        resumed = true
                        cont.resume(returning: image)
                    }
                }
            }
            if let image {
                tripPhotos[trip.id] = image
            }
        }
    }
}
