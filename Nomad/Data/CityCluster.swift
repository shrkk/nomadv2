import CoreLocation

// CityCluster — groups TripDocuments by geographic proximity for the Country Detail View.
// Used by Plans 02 and 03 to power per-city sections on the country detail sheet.

let kCityClusterRadiusKm: Double = 50.0

struct CityCluster: Identifiable {
    let id = UUID()
    var cityName: String
    var centroid: CLLocationCoordinate2D
    var trips: [TripDocument]

    var tripCount: Int { trips.count }

    var totalDistanceKm: Double {
        trips.reduce(0) { $0 + $1.distanceMeters } / 1000
    }

    var dateRange: (start: Date, end: Date) {
        let start = trips.map(\.startDate).min() ?? Date()
        let end = trips.map(\.endDate).max() ?? Date()
        return (start: start, end: end)
    }
}

/// Groups trips by geographic proximity using greedy centroid clustering.
/// Trips without a coordinate are skipped.
/// - Parameters:
///   - trips: All trips to cluster (e.g. for a specific country).
///   - radiusKm: Maximum distance from cluster centroid to include a trip. Default 50 km.
/// - Returns: Clusters sorted by trip count descending (most-visited city first).
func clusterTripsByProximity(_ trips: [TripDocument], radiusKm: Double = kCityClusterRadiusKm) -> [CityCluster] {
    var clusters: [CityCluster] = []

    for trip in trips {
        guard let coordinate = trip.coordinate else { continue }
        let tripLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // Find the nearest existing cluster within radiusKm.
        if let index = clusters.firstIndex(where: { cluster in
            let centroidLocation = CLLocation(latitude: cluster.centroid.latitude, longitude: cluster.centroid.longitude)
            return centroidLocation.distance(from: tripLocation) / 1000 <= radiusKm
        }) {
            clusters[index].trips.append(trip)
        } else {
            // Create a new cluster with this trip as the seed.
            let newCluster = CityCluster(
                cityName: trip.cityName,
                centroid: coordinate,
                trips: [trip]
            )
            clusters.append(newCluster)
        }
    }

    // Set each cluster's cityName to the most frequently occurring cityName among member trips.
    for index in clusters.indices {
        let nameCounts = clusters[index].trips.reduce(into: [String: Int]()) { counts, t in
            counts[t.cityName, default: 0] += 1
        }
        if let mostCommon = nameCounts.max(by: { $0.value < $1.value }) {
            clusters[index].cityName = mostCommon.key
        }
    }

    // Sort by trip count descending.
    return clusters.sorted { $0.tripCount > $1.tripCount }
}
