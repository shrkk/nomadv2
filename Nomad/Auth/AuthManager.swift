import FirebaseAuth
import Observation

// AuthManager — Firebase auth state observer.
// Listens for auth state changes and exposes AuthState enum for routing in NomadApp.
// D-09: @Observable pattern for SwiftUI integration
// D-10: AuthState enum drives root view routing
// D-11: .loading prevents flash of wrong UI on cold start
//
// Swift 6 note: deinit is nonisolated so it cannot access @MainActor-isolated storage.
// We store the listener handle in a nonisolated wrapper class so deinit can reach it.

enum AuthState {
    case loading
    case unauthenticated
    case authenticated(FirebaseAuth.User)
}

/// Nonisolated box so `deinit` (which is nonisolated) can remove the Firebase listener
/// without crossing the @MainActor isolation boundary.
private final class ListenerHandleBox: @unchecked Sendable {
    var handle: AuthStateDidChangeListenerHandle?
}

@Observable @MainActor final class AuthManager {
    var authState: AuthState = .loading

    // Stored in a nonisolated box so deinit can access it without actor isolation violation.
    private let handleBox = ListenerHandleBox()

    init() {
        handleBox.handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.authState = .authenticated(user)
                } else {
                    self?.authState = .unauthenticated
                }
            }
        }
    }

    deinit {
        if let handle = handleBox.handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    /// Sign up a new user with email and password.
    @discardableResult
    func signUp(email: String, password: String) async throws -> FirebaseAuth.User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user
    }

    /// Sign in an existing user with email and password.
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    /// Sign out the current user.
    func signOut() throws {
        try Auth.auth().signOut()
    }
}
