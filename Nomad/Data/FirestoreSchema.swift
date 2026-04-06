import FirebaseFirestore

// FirestoreSchema — type-safe Firestore path constants and helpers.
// D-12: Centralised collection/document paths prevent string literal scatter.
// D-13: routePoints subcollection path.
// D-14: Trip document field keys.
// D-15: User document field keys.

enum FirestoreSchema {
    static let users = "users"
    static let usernames = "usernames"

    static func userDoc(_ uid: String) -> DocumentReference {
        Firestore.firestore().collection(users).document(uid)
    }

    static func tripsCollection(_ uid: String) -> CollectionReference {
        userDoc(uid).collection("trips")
    }

    static func tripDoc(_ uid: String, tripId: String) -> DocumentReference {
        tripsCollection(uid).document(tripId)
    }

    static func routePointsCollection(_ uid: String, tripId: String) -> CollectionReference {
        tripDoc(uid, tripId: tripId).collection("routePoints")
    }

    static func usernameDoc(_ handle: String) -> DocumentReference {
        Firestore.firestore().collection(usernames).document(handle.lowercased())
    }

    /// Trip document field keys (D-14)
    enum TripFields {
        static let routePreview = "routePreview"
        static let visitedCountryCodes = "visitedCountryCodes"
        static let placeCounts = "placeCounts"
        static let cityName = "cityName"
        static let startDate = "startDate"
        static let endDate = "endDate"
        static let stepCount = "stepCount"
        static let distanceMeters = "distanceMeters"
        static let userId = "userId"
    }

    /// User document field keys (D-15)
    enum UserFields {
        static let handle = "handle"
        static let email = "email"
        static let homeCityName = "homeCityName"
        static let homeCityLatitude = "homeCityLatitude"
        static let homeCityLongitude = "homeCityLongitude"
        static let discoveryScope = "discoveryScope"
        static let geofenceRadius = "geofenceRadius"
        static let createdAt = "createdAt"
        static let onboardingComplete = "onboardingComplete"
    }
}
