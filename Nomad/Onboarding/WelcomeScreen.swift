import SwiftUI

// WelcomeScreen — Screen 1 of the onboarding flow.
// D-02: Globe-dark background (solid Color.Nomad.globeBackground), Playfair tagline, amber CTA.
// UI-SPEC Screen 1: app name at ~35% screen height, tagline below, CTA pinned to bottom.
// NOTE: Live RealityKit globe is deferred — solid background color used per plan instructions.

struct WelcomeScreen: View {
    var coordinator: OnboardingCoordinator

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background — globe environment color
                Color.Nomad.globeBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.35)

                    // App name
                    Text("Nomad")
                        .font(AppFont.title())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    // Tagline
                    Text("The world is yours to explore.")
                        .font(AppFont.subheading())
                        .foregroundColor(Color.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)

                    Spacer()

                    // CTA + sign-in link, pinned to bottom
                    VStack(spacing: 0) {
                        // Get started CTA
                        Button {
                            coordinator.isSignInMode = false
                            coordinator.advance()
                        } label: {
                            Text("Get started")
                                .font(AppFont.buttonLabel())
                                .foregroundColor(Color.Nomad.panelBlack)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.Nomad.accent)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)

                        // Sign-in link
                        HStack(spacing: 0) {
                            Text("Already have an account? ")
                                .font(AppFont.caption())
                                .foregroundColor(Color.white.opacity(0.6))
                            Button {
                                coordinator.isSignInMode = true
                                coordinator.advance()
                            } label: {
                                Text("Sign in")
                                    .font(AppFont.caption())
                                    .foregroundColor(Color.white.opacity(0.6))
                                    .underline()
                            }
                        }
                        .padding(.top, 16)
                    }
                    .padding(.bottom, 48)
                }
            }
        }
    }
}
