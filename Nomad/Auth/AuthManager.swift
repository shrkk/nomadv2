@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore
@preconcurrency import GoogleSignIn
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
    /// True once the user has completed the full onboarding flow.
    /// Seeded from UserDefaults on launch; confirmed/corrected via Firestore async check.
    var onboardingComplete: Bool = UserDefaults.standard.bool(forKey: "onboardingComplete")

    // Stored in a nonisolated box so deinit can access it without actor isolation violation.
    private let handleBox = ListenerHandleBox()

    init() {
        handleBox.handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.authState = .authenticated(user)
                    await self?.syncOnboardingStatus(uid: user.uid)
                } else {
                    self?.authState = .unauthenticated
                    self?.onboardingComplete = false
                }
            }
        }
    }

    /// Called at the end of HomeCityScreen — marks the user as fully onboarded.
    func markOnboardingComplete() {
        onboardingComplete = true
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
    }

    /// Fast-path: UserDefaults; slow-path: Firestore (handles new-device sign-in for returning users).
    private func syncOnboardingStatus(uid: String) async {
        if UserDefaults.standard.bool(forKey: "onboardingComplete") {
            onboardingComplete = true
            return
        }
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            let complete = doc.data()?["onboardingComplete"] as? Bool ?? false
            onboardingComplete = complete
            if complete {
                UserDefaults.standard.set(true, forKey: "onboardingComplete")
            }
        } catch {
            // Network failure — leave onboardingComplete as false; user will re-enter flow.
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
        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: plistPath),
              let clientID = plist["CLIENT_ID"] as? String else {
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
