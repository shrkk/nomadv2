import FirebaseAuth
import GoogleSignIn
import Observation
import UIKit

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
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }

    /// Sign in with Google. Requires CLIENT_ID in GoogleService-Info.plist (enable Google Sign-In in Firebase Console first).
    func signInWithGoogle() async throws {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "CLIENT_ID") as? String else {
            throw GoogleSignInError.notConfigured
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = await windowScene.windows.first?.rootViewController else {
            throw GoogleSignInError.noRootViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.missingToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await Auth.auth().signIn(with: credential)
    }
}

enum GoogleSignInError: LocalizedError {
    case notConfigured
    case noRootViewController
    case missingToken

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Google Sign-In is not configured. Enable it in Firebase Console."
        case .noRootViewController: return "Unable to present Google Sign-In."
        case .missingToken: return "Google Sign-In failed — missing ID token."
        }
    }
}
