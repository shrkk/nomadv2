import FirebaseFirestore

// FirebaseService — INFRA-03 stub validation.
// Provides async writeStubUser / readStubUser for Firestore connectivity proof.
// Runtime requires GoogleService-Info.plist and Firestore enabled in test mode.
// Source: INFRA-03 (REQUIREMENTS.md), 01-01-PLAN.md Task 2.
//
// SECURITY NOTE (threat model): Firestore test mode is Phase 1 only.
// Phase 2 adds Firebase Auth + security rules. Test mode must NOT ship to production.
struct FirebaseService {
    private let db = Firestore.firestore()

    func writeStubUser() async throws {
        try await db.collection("users").document("stub-user-01").setData([
            "handle": "nomad_test",
            "visitedCountryCodes": ["JP", "FR", "AU", "KE", "BR"],
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func readStubUser() async throws -> [String: Any] {
        let document = try await db.collection("users").document("stub-user-01").getDocument()
        return document.data() ?? [:]
    }
}
