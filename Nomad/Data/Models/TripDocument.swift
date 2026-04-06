import FirebaseFirestore
import CoreLocation

// TripDocument — read-only model decoded from Firestore trip documents.
// T-03-01: All fetches scoped to Auth.auth().currentUser?.uid (enforced in TripService).
// T-03-02: Firestore data is server-authoritative; client reads own data only.
// Matches FirestoreSchema.TripFields field keys exactly (D-14).

struct TripDocument: Identifiable {
    let id: String                         // Firestore document ID = tripId
    let cityName: String                   // TripFields.cityName
    let startDate: Date                    // TripFields.startDate (Timestamp -> Date)
    let endDate: Date                      // TripFields.endDate (Timestamp -> Date)
    let stepCount: Int                     // TripFields.stepCount
    let distanceMeters: Double             // TripFields.distanceMeters
    let routePreview: [[Double]]           // TripFields.routePreview (50-pt [[lat, lon]])
    let visitedCountryCodes: [String]      // TripFields.visitedCountryCodes
    let placeCounts: [String: Int]         // TripFields.placeCounts

    /// Derived: first route preview point as coordinate for globe pinpoint placement.
    var coordinate: CLLocationCoordinate2D? {
        guard let first = routePreview.first, first.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: first[0], longitude: first[1])
    }

    /// Initialize from Firestore QueryDocumentSnapshot using manual decoding.
    /// Matches existing TripService manual setData pattern — not @DocumentID.
    /// Returns nil if required fields (cityName, startDate, endDate, routePreview) are absent.
    init?(snapshot: QueryDocumentSnapshot) {
        let data = snapshot.data()
        guard
            let cityName = data[FirestoreSchema.TripFields.cityName] as? String,
            let startTimestamp = data[FirestoreSchema.TripFields.startDate] as? Timestamp,
            let endTimestamp = data[FirestoreSchema.TripFields.endDate] as? Timestamp,
            let rawPreview = data[FirestoreSchema.TripFields.routePreview] as? [Double]
        else { return nil }
        // Re-pair flat [lat,lon,lat,lon,...] → [[lat,lon]] stored as nested array in memory.
        let preview: [[Double]] = stride(from: 0, to: rawPreview.count - 1, by: 2).map {
            [rawPreview[$0], rawPreview[$0 + 1]]
        }

        self.id = snapshot.documentID
        self.cityName = cityName
        self.startDate = startTimestamp.dateValue()
        self.endDate = endTimestamp.dateValue()
        self.stepCount = data[FirestoreSchema.TripFields.stepCount] as? Int ?? 0
        self.distanceMeters = data[FirestoreSchema.TripFields.distanceMeters] as? Double ?? 0
        self.routePreview = preview
        self.visitedCountryCodes = data[FirestoreSchema.TripFields.visitedCountryCodes] as? [String] ?? []
        self.placeCounts = data[FirestoreSchema.TripFields.placeCounts] as? [String: Int] ?? [:]
    }

    /// Memberwise initializer for previews and testing.
    init(
        id: String,
        cityName: String,
        startDate: Date,
        endDate: Date,
        stepCount: Int,
        distanceMeters: Double,
        routePreview: [[Double]],
        visitedCountryCodes: [String],
        placeCounts: [String: Int]
    ) {
        self.id = id
        self.cityName = cityName
        self.startDate = startDate
        self.endDate = endDate
        self.stepCount = stepCount
        self.distanceMeters = distanceMeters
        self.routePreview = routePreview
        self.visitedCountryCodes = visitedCountryCodes
        self.placeCounts = placeCounts
    }
}
