import FirebaseFirestore
import CoreLocation
import SwiftData

// TripService — Firestore trip finalization and routePoints batch sync.
// D-12: Trips written to users/{uid}/trips/{tripId}.
// D-13: Route points written to routePoints subcollection in 400-op batches.
// D-14: Trip document written with all denormalized fields.
// PLACE-04: placeCounts aggregated from PlaceCategoryService and written to trip doc.

@MainActor
final class TripService {
    private let db = Firestore.firestore()
    private let placeCategoryService = PlaceCategoryService()

    /// Finalize a trip: simplify route, categorize stops, write trip doc + routePoints to Firestore
    /// Called after user stops recording and names the trip.
    func finalizeTrip(
        userId: String,
        tripId: String,
        cityName: String,
        startDate: Date,
        endDate: Date,
        routePoints: [RoutePoint],
        stepCount: Int,
        distanceMeters: Double
    ) async throws {
        // 1. Simplify route via RDP
        let (_, previewRoute) = RouteSimplifier.simplifyRoute(routePoints)

        // 2. Extract unique stop coordinates (sample every ~20th point for categorization)
        let coordinates = RouteSimplifier.coordinatesFromRoutePoints(routePoints)
        let stopCoordinates = sampleStopCoordinates(from: coordinates, every: 20)

        // 3. Categorize stops via MKLocalPointsOfInterestRequest
        let placeCounts = await placeCategoryService.categorizeStops(stopCoordinates)

        // 4. Determine visited country codes from route endpoints
        let countryCodes = await detectCountryCodes(from: coordinates)

        // 5. Write trip document with all D-14 denormalized fields
        let tripRef = FirestoreSchema.tripDoc(userId, tripId: tripId)
        try await tripRef.setData([
            FirestoreSchema.TripFields.routePreview: previewRoute,
            FirestoreSchema.TripFields.visitedCountryCodes: countryCodes,
            FirestoreSchema.TripFields.placeCounts: placeCounts,
            FirestoreSchema.TripFields.cityName: cityName,
            FirestoreSchema.TripFields.startDate: Timestamp(date: startDate),
            FirestoreSchema.TripFields.endDate: Timestamp(date: endDate),
            FirestoreSchema.TripFields.stepCount: stepCount,
            FirestoreSchema.TripFields.distanceMeters: distanceMeters,
            FirestoreSchema.TripFields.userId: userId,
        ])

        // 6. Batch-write routePoints to subcollection (400 per batch — safe under 500 limit)
        try await syncRoutePoints(points: routePoints, userId: userId, tripId: tripId)
    }

    /// Batch-write route points to Firestore subcollection
    /// Chunks into batches of 400 to stay under Firestore's 500-operation limit
    func syncRoutePoints(points: [RoutePoint], userId: String, tripId: String) async throws {
        let batchSize = 400
        let chunks = stride(from: 0, to: points.count, by: batchSize).map {
            Array(points[$0..<min($0 + batchSize, points.count)])
        }

        for chunk in chunks {
            let batch = db.batch()
            for point in chunk {
                let ref = FirestoreSchema.routePointsCollection(userId, tripId: tripId).document()
                batch.setData([
                    "latitude": point.latitude,
                    "longitude": point.longitude,
                    "timestamp": Timestamp(date: point.timestamp),
                    "accuracy": point.accuracy,
                    "altitude": point.altitude
                ], forDocument: ref)
            }
            try await batch.commit()
        }
    }

    /// Update user document with visited country codes (aggregate across all trips)
    func updateUserVisitedCountries(userId: String, newCodes: [String]) async throws {
        let userRef = FirestoreSchema.userDoc(userId)
        try await userRef.updateData([
            "visitedCountryCodes": FieldValue.arrayUnion(newCodes)
        ])
    }

    // MARK: - Private

    /// Sample every Nth coordinate for POI categorization (avoids querying every GPS point)
    private func sampleStopCoordinates(from coordinates: [CLLocationCoordinate2D], every n: Int) -> [CLLocationCoordinate2D] {
        guard !coordinates.isEmpty else { return [] }
        var samples: [CLLocationCoordinate2D] = []
        for i in stride(from: 0, to: coordinates.count, by: max(1, n)) {
            samples.append(coordinates[i])
        }
        // Always include the last coordinate
        if let last = coordinates.last, samples.last?.latitude != last.latitude || samples.last?.longitude != last.longitude {
            samples.append(last)
        }
        return samples
    }

    /// Reverse-geocode a sample of coordinates to extract ISO country codes
    private func detectCountryCodes(from coordinates: [CLLocationCoordinate2D]) async -> [String] {
        let geocoder = CLGeocoder()
        var codes = Set<String>()

        // Sample first, last, and a few middle points
        let sampleIndices: [Int] = {
            guard coordinates.count > 2 else { return Array(0..<coordinates.count) }
            let mid = coordinates.count / 2
            return [0, mid, coordinates.count - 1]
        }()

        for idx in sampleIndices {
            let coord = coordinates[idx]
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
               let code = placemarks.first?.isoCountryCode {
                codes.insert(code)
            }
        }

        return Array(codes)
    }
}
