@preconcurrency import MapKit
import CoreLocation

// PlaceCategoryService — POI-based place categorization for traveler archetype computation.
// PLACE-01: Uses MKLocalPointsOfInterestRequest (NOT CLPlacemark).
// PLACE-02: Maps ~30 MKPointOfInterestCategory cases to 6 Nomad scoring dimensions.
// PLACE-03: Caches results by 2-decimal coordinate key (~1.1km grid cell).
// T-02-14: 200ms rate limit delay between sequential MKLocalSearch calls.

actor PlaceCategoryService {
    /// Cache: coordinate key -> place counts dictionary
    /// Key format: "lat_2dp,lon_2dp" (~1.1km grid cell)
    private var cache: [String: [String: Int]] = [:]

    /// The 6 scoring dimensions used for archetype computation
    static let dimensions = ["Food", "Culture", "Nature", "Nightlife", "Wellness", "Local"]

    /// Categorize a coordinate by querying nearby POIs
    /// Returns a dictionary of dimension -> count, e.g. {"Food": 3, "Culture": 1, ...}
    func categorize(coordinate: CLLocationCoordinate2D) async throws -> [String: Int] {
        let key = coordinateKey(coordinate)
        if let cached = cache[key] { return cached }

        // 200ms delay between sequential calls to avoid potential throttling
        try await Task.sleep(for: .milliseconds(200))

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 200,
            longitudinalMeters: 200
        )
        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        // Include all categories we care about mapping
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: Array(categoryToDimension.keys))

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        var counts = emptyPlaceCounts()
        for item in response.mapItems {
            if let category = item.pointOfInterestCategory,
               let dimension = categoryToDimension[category] {
                counts[dimension, default: 0] += 1
            }
        }

        cache[key] = counts
        return counts
    }

    /// Categorize multiple coordinates and aggregate into total place counts
    func categorizeStops(_ coordinates: [CLLocationCoordinate2D]) async -> [String: Int] {
        var aggregated = emptyPlaceCounts()
        for coord in coordinates {
            if let counts = try? await categorize(coordinate: coord) {
                for (dimension, count) in counts {
                    aggregated[dimension, default: 0] += count
                }
            }
        }
        return aggregated
    }

    // MARK: - Private

    /// Round coordinate to 2 decimal places for ~1.1km grid cell cache key
    private func coordinateKey(_ coord: CLLocationCoordinate2D) -> String {
        let lat = (coord.latitude * 100).rounded() / 100
        let lon = (coord.longitude * 100).rounded() / 100
        return "\(lat),\(lon)"
    }

    private func emptyPlaceCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for dim in PlaceCategoryService.dimensions {
            counts[dim] = 0
        }
        return counts
    }

    /// Complete mapping from MKPointOfInterestCategory to Nomad's 6 scoring dimensions
    /// Categories not in this dictionary are skipped (gasStation, parking, atm, airport, etc.)
    private let categoryToDimension: [MKPointOfInterestCategory: String] = [
        // Food
        .restaurant: "Food",
        .cafe: "Food",
        .bakery: "Food",
        .foodMarket: "Food",
        .brewery: "Food",    // also has Nightlife aspect but primary mapping is Food
        .winery: "Food",

        // Culture
        .movieTheater: "Culture",
        .theater: "Culture",
        .museum: "Culture",
        .library: "Culture",
        .university: "Culture",
        .aquarium: "Culture",
        .zoo: "Culture",
        .amusementPark: "Culture",
        .stadium: "Culture",

        // Nature
        .park: "Nature",
        .nationalPark: "Nature",
        .beach: "Nature",
        .campground: "Nature",
        .marina: "Nature",

        // Nightlife
        .nightlife: "Nightlife",

        // Wellness
        .fitnessCenter: "Wellness",
        .hospital: "Wellness",
        .pharmacy: "Wellness",

        // Local / Neighborhood
        .store: "Local",
        .bank: "Local",
        .postOffice: "Local",
        .publicTransport: "Local",
        .school: "Local",
        .hotel: "Local",
    ]
}
