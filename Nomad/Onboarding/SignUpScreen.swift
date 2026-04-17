import SwiftUI
@preconcurrency import FirebaseAuth
@preconcurrency import GoogleSignInSwift

// SignUpScreen — Screen 2 of the onboarding flow.
// Handles both "Create account" (sign-up mode) and "Sign in" (returning user mode).
// D-09: Uses AuthManager from environment to sign up or sign in.
// UI-SPEC Screen 2: cream background, conditional header, email/password fields, Firebase error mapping.

struct SignUpScreen: View {
    var coordinator: OnboardingCoordinator
    @Environment(AuthManager.self) private var authManager

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var isGoogleLoading: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text(coordinator.isSignInMode ? "Welcome back" : "Create your account")
                    .font(AppFont.title())
                    .foregroundColor(Color.Nomad.textPrimary)
                    .padding(.top, 32)

                // Subheader (sign-up mode only)
                if !coordinator.isSignInMode {
                    Text("We'll keep your journey private and secure.")
                        .font(AppFont.body())
                        .foregroundColor(Color.Nomad.textSecondary)
                        .padding(.top, 8)
                }

                // Email field
                emailField
                    .padding(.top, 32)

                // Password field + hint
                passwordField
                    .padding(.top, 16)

                if !coordinator.isSignInMode {
                    Text("8+ characters")
                        .font(AppFont.caption())
                        .foregroundColor(Color.Nomad.textSecondary)
                        .padding(.top, 4)
                }

                // CTA
                ctaButton
                    .padding(.top, 32)

                // Divider
                HStack {
                    Rectangle().frame(height: 1).foregroundColor(Color.Nomad.surfaceBorder.opacity(0.10))
                    Text("or").font(AppFont.caption()).foregroundColor(Color.Nomad.textSecondary)
                    Rectangle().frame(height: 1).foregroundColor(Color.Nomad.surfaceBorder.opacity(0.10))
                }
                .padding(.top, 20)

                // Google Sign-In
                googleButton
                    .padding(.top, 12)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.Nomad.panelBlack.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Email field

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Email address", text: $email)
                .font(AppFont.body())
                .foregroundColor(Color.Nomad.textPrimary)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .frame(height: 48)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.Nomad.globeBackground.opacity(0.50))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.Nomad.surfaceBorder.opacity(0.12), lineWidth: 1))
                )
                .cornerRadius(12)

            if let error = errorMessage, error.contains("email") || error.contains("Email") {
                Text(error)
                    .font(AppFont.caption())
                    .foregroundColor(Color.Nomad.destructive)
            }
        }
    }

    // MARK: - Password field

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .trailing) {
                Group {
                    if showPassword {
                        TextField("Password", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }
                }
                .font(AppFont.body())
                .foregroundColor(Color.Nomad.textPrimary)
                .frame(height: 48)
                .padding(.horizontal, 12)
                .padding(.trailing, 44)

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye" : "eye.slash")
                        .font(.system(size: 16))
                        .foregroundColor(Color.Nomad.textSecondary)
                        .frame(width: 44, height: 44)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.Nomad.globeBackground.opacity(0.50))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.Nomad.surfaceBorder.opacity(0.12), lineWidth: 1))
            )
            .cornerRadius(12)

            if let error = errorMessage, !error.contains("email") && !error.contains("Email") {
                Text(error)
                    .font(AppFont.caption())
                    .foregroundColor(Color.Nomad.destructive)
            }
        }
    }

    // MARK: - CTA button

    private var ctaButton: some View {
        let label = coordinator.isSignInMode ? "Sign in" : "Create account"
        let isDisabled = email.isEmpty || password.isEmpty || isLoading

        return Button {
            Task { await performAuth() }
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(Color.Nomad.panelBlack)
                } else {
                    Text(label)
                        .font(AppFont.buttonLabel())
                        .foregroundColor(Color.Nomad.panelBlack)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.Nomad.accent.opacity(isDisabled ? 0.3 : 1.0))
            .cornerRadius(12)
        }
        .disabled(isDisabled)
    }

    // MARK: - Auth logic

    private func performAuth() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if coordinator.isSignInMode {
                try await authManager.signIn(email: email, password: password)
                // AuthManager listener will flip authState → NomadApp routes to GlobeView
                // once onboardingComplete syncs. Advance coordinator so the user isn't
                // stuck on the sign-up screen while that async check runs.
                coordinator.advance()
            } else {
                _ = try await authManager.signUp(email: email, password: password)
                coordinator.email = email
                coordinator.advance()
            }
        } catch let nsError as NSError {
            errorMessage = mapFirebaseError(nsError)
        }
    }

    // MARK: - Google button

    private var googleButton: some View {
        Button {
            Task { await performGoogleSignIn() }
        } label: {
            ZStack {
                if isGoogleLoading {
                    ProgressView().tint(Color.Nomad.textPrimary)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                        Text("Continue with Google")
                            .font(AppFont.buttonLabel())
                            .foregroundColor(Color.Nomad.textPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.Nomad.globeBackground.opacity(0.50))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.Nomad.surfaceBorder.opacity(0.12), lineWidth: 1))
        }
        .disabled(isGoogleLoading)
    }

    private func performGoogleSignIn() async {
        isGoogleLoading = true
        errorMessage = nil
        defer { isGoogleLoading = false }
        do {
            try await authManager.signInWithGoogle()
            // Advance to HandleScreen — NomadApp stays on OnboardingView until onboarding completes.
            coordinator.advance()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mapFirebaseError(_ error: NSError) -> String {
        // Firebase Auth errors come back as NSError with domain "FIRAuthErrorDomain"
        // and codes matching AuthErrorCode enum values.
        let code = AuthErrorCode(rawValue: error.code)
        switch code {
        case .emailAlreadyInUse:
            return "An account with this email already exists. Sign in instead?"
        case .invalidEmail:
            return "Enter a valid email address."
        case .weakPassword:
            return "Password must be at least 8 characters."
        case .wrongPassword, .userNotFound:
            return "Invalid email or password."
        default:
            return "Something went wrong. Check your connection and try again."
        }
    }
}
