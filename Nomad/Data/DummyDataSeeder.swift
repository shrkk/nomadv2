@preconcurrency import FirebaseFirestore
import FirebaseAuth

/// Seeds dummy trip documents for demo/testing purposes.
/// All seeded trips use IDs prefixed with "dummy-" so they can be identified and removed.
/// Call `DummyDataSeeder.seed()` to add data, `DummyDataSeeder.removeSeed()` to undo.
@MainActor
enum DummyDataSeeder {

    static let dummyPrefix = "dummy-"

    private struct SeedTrip {
        let id: String
        let cityName: String
        let countryCode: String
        let lat: Double
        let lon: Double
        let daysAgo: Int       // trip start = N days ago, end = N-1 days ago
        let steps: Int
        let distanceMeters: Double
    }

    private static let seedTrips: [SeedTrip] = [
        SeedTrip(id: "dummy-india",       cityName: "Mumbai",     countryCode: "IN", lat: 19.076,  lon: 72.8777,    daysAgo: 90,  steps: 14200, distanceMeters: 11500),
        SeedTrip(id: "dummy-japan",       cityName: "Tokyo",      countryCode: "JP", lat: 35.6762, lon: 139.6503,   daysAgo: 75,  steps: 18300, distanceMeters: 15200),
        SeedTrip(id: "dummy-italy",       cityName: "Rome",       countryCode: "IT", lat: 41.9028, lon: 12.4964,    daysAgo: 60,  steps: 16800, distanceMeters: 13100),
        SeedTrip(id: "dummy-uk",          cityName: "London",     countryCode: "GB", lat: 51.5074, lon: -0.1278,    daysAgo: 45,  steps: 15600, distanceMeters: 12400),
        SeedTrip(id: "dummy-iceland",     cityName: "Reykjavik",  countryCode: "IS", lat: 64.1466, lon: -21.9426,   daysAgo: 30,  steps: 12100, distanceMeters: 9800),
        SeedTrip(id: "dummy-mexico",      cityName: "Mexico City", countryCode: "MX", lat: 19.4326, lon: -99.1332,  daysAgo: 20,  steps: 13500, distanceMeters: 10700),
        SeedTrip(id: "dummy-switzerland", cityName: "Zurich",     countryCode: "CH", lat: 47.3769, lon: 8.5417,     daysAgo: 10,  steps: 11800, distanceMeters: 9200),
    ]

    /// Seed dummy trips into Firestore for the current user.
    static func seed() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[DummySeeder] No authenticated user")
            return
        }

        let db = Firestore.firestore()
        let now = Date()

        for trip in seedTrips {
            let start = Calendar.current.date(byAdding: .day, value: -trip.daysAgo, to: now)!
            let end = Calendar.current.date(byAdding: .day, value: -(trip.daysAgo - 1), to: now)!

            // Small route preview: just a single point (enough for globe pin placement)
            let flatPreview: [Double] = [trip.lat, trip.lon, trip.lat + 0.01, trip.lon + 0.01]

            let data: [String: Any] = [
                FirestoreSchema.TripFields.cityName: trip.cityName,
                FirestoreSchema.TripFields.startDate: Timestamp(date: start),
                FirestoreSchema.TripFields.endDate: Timestamp(date: end),
                FirestoreSchema.TripFields.stepCount: trip.steps,
                FirestoreSchema.TripFields.distanceMeters: trip.distanceMeters,
                FirestoreSchema.TripFields.routePreview: flatPreview,
                FirestoreSchema.TripFields.visitedCountryCodes: [trip.countryCode],
                FirestoreSchema.TripFields.placeCounts: ["culture": 3, "food": 2, "nature": 1],
                FirestoreSchema.TripFields.userId: uid,
                FirestoreSchema.TripFields.locality: trip.cityName,
            ]

            let ref = FirestoreSchema.tripsCollection(uid).document(trip.id)
            do {
                try await ref.setData(data)
                print("[DummySeeder] Wrote trip: \(trip.id)")
            } catch {
                print("[DummySeeder] Failed to write \(trip.id): \(error)")
            }
        }

        // Update user doc visitedCountryCodes
        let codes = seedTrips.map(\.countryCode)
        let userRef = FirestoreSchema.userDoc(uid)
        do {
            try await userRef.updateData([
                "visitedCountryCodes": FieldValue.arrayUnion(codes)
            ])
            print("[DummySeeder] Updated user visitedCountryCodes with \(codes)")
        } catch {
            print("[DummySeeder] Failed to update user doc: \(error)")
        }

        print("[DummySeeder] ✅ Seeding complete — restart the app to see changes on globe/passport")
    }

    /// Remove all dummy trips and their country codes from the current user's data.
    static func removeSeed() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[DummySeeder] No authenticated user")
            return
        }

        let db = Firestore.firestore()

        // Delete dummy trip documents
        for trip in seedTrips {
            let ref = FirestoreSchema.tripsCollection(uid).document(trip.id)
            do {
                try await ref.delete()
                print("[DummySeeder] Deleted trip: \(trip.id)")
            } catch {
                print("[DummySeeder] Failed to delete \(trip.id): \(error)")
            }
        }

        // Remove dummy country codes from user doc
        let codes = seedTrips.map(\.countryCode)
        let userRef = FirestoreSchema.userDoc(uid)
        do {
            try await userRef.updateData([
                "visitedCountryCodes": FieldValue.arrayRemove(codes)
            ])
            print("[DummySeeder] Removed country codes from user doc")
        } catch {
            print("[DummySeeder] Failed to update user doc: \(error)")
        }

        print("[DummySeeder] ✅ Removal complete — restart the app to refresh")
    }
}
