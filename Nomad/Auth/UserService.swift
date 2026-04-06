import FirebaseFirestore
import Observation

// UserService — Firestore user document and handle management.
// D-04: Handle uniqueness checked via usernames collection
// D-12: Atomic batch write for user doc + username reservation
// D-15: User document fields and onboarding completion update

@Observable @MainActor final class UserService {
    private let db = Firestore.firestore()

    /// Check whether a handle is available (not yet taken).
    /// Returns false on network/read errors to fail safely.
    func isHandleAvailable(_ handle: String) async -> Bool {
        do {
            let doc = try await db.collection("usernames").document(handle.lowercased()).getDocument()
            return !doc.exists
        } catch {
            return false
        }
    }

    /// Atomically create the user document and reserve the username.
    /// Writes users/{uid} and usernames/{handle.lowercased()} in a single batch.
    func createUserWithHandle(uid: String, handle: String, email: String) async throws {
        let batch = db.batch()

        let userRef = db.collection("users").document(uid)
        batch.setData([
            "handle": handle,
            "email": email,
            "createdAt": FieldValue.serverTimestamp(),
            "onboardingComplete": false
        ], forDocument: userRef)

        let usernameRef = db.collection("usernames").document(handle.lowercased())
        batch.setData(["uid": uid], forDocument: usernameRef)

        try await batch.commit()
    }

    /// Update the user document with home city and onboarding completion.
    /// Called at the end of onboarding flow (Plan 02).
    func updateUserOnboardingComplete(
        uid: String,
        homeCityName: String,
        homeCityLatitude: Double,
        homeCityLongitude: Double,
        discoveryScope: String,
        geofenceRadius: Double
    ) async throws {
        try await db.collection("users").document(uid).updateData([
            "homeCityName": homeCityName,
            "homeCityLatitude": homeCityLatitude,
            "homeCityLongitude": homeCityLongitude,
            "discoveryScope": discoveryScope,
            "geofenceRadius": geofenceRadius,
            "onboardingComplete": true
        ])
    }

    /// Fetch a user document as a raw data dictionary.
    func fetchUserDocument(uid: String) async throws -> [String: Any]? {
        let document = try await db.collection("users").document(uid).getDocument()
        return document.data()
    }
}
