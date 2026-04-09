import SwiftUI

// PanelGlassSurfaceModifier — canonical glass surface for all sheet panels (Phase 03.2 redesign).
// 4-layer background stack: panelBlack base + ultraThinMaterial blur + dark overlay + hairline border.
// Corner radius: 20pt top corners, 0pt bottom corners (extends to safe area edge).
// Source: D-02 (CONTEXT.md), UI-SPEC Glassmorphic Surface Contract, PanelGradient Replacement section.
struct PanelGlassSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Layer 1: Solid opaque base
                    Color.Nomad.panelBlack

                    // Layer 2: Material blur
                    Rectangle()
                        .fill(.ultraThinMaterial)

                    // Layer 3: Darkness reinforcement overlay
                    Color.black.opacity(0.35)

                    // Layer 4: Edge darkening vignette
                    RadialGradient(
                        colors: [.clear, Color.black.opacity(0.20)],
                        center: .center,
                        startRadius: UIScreen.main.bounds.width * 0.4,
                        endRadius: UIScreen.main.bounds.width * 0.9
                    )
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 20
                    )
                )
                .overlay(
                    // White hairline border — top corners only, 1pt at 20% opacity
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 20
                    )
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
            )
    }
}

extension View {
    /// Glass surface recipe — Phase 03.2 redesign (glassmorphic black/white)
    func panelGlassSurface() -> some View {
        modifier(PanelGlassSurfaceModifier())
    }

    /// Backward-compatible alias — calls panelGlassSurface()
    func panelGradient() -> some View {
        panelGlassSurface()
    }
}

// MARK: - GlassButtonStyle

/// ButtonStyle for all glass buttons — capsule shape with material blur and hairline border.
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.35))
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.20), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - InnerCardSurface

/// ViewModifier for inner cards — StatsRow, TripLogCard, CityThumbnailCard.
struct InnerCardSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func innerCardSurface() -> some View {
        modifier(InnerCardSurfaceModifier())
    }
}

// MARK: - FloatingPillSurface

/// ViewModifier for floating pills — RecordingPill, JourneyPill.
/// 3-layer capsule: material + panelBlack overlay + hairline border + drop shadow.
struct FloatingPillSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(Color.Nomad.panelBlack.opacity(0.80))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.20), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.40), radius: 12, x: 0, y: 6)
            )
    }
}

extension View {
    func floatingPillSurface() -> some View {
        modifier(FloatingPillSurfaceModifier())
    }
}

// MARK: - Debug Preview

#if DEBUG
#Preview {
    ZStack {
        Color.Nomad.globeBackground.ignoresSafeArea()
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Capsule()
                        .fill(Color.Nomad.textSecondary)
                        .frame(width: 36, height: 4)
                    Spacer()
                }
                .padding(.top, 8)
                Text("Glass Surface Preview")
                    .font(AppFont.title())
                    .foregroundStyle(Color.Nomad.textPrimary)
                Text("ultraThinMaterial + dark overlay + hairline border.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.Nomad.textSecondary)

                // InnerCardSurface example
                HStack {
                    Text("Inner Card")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.textPrimary)
                    Spacer()
                    Text("stat")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.textSecondary)
                }
                .padding(12)
                .innerCardSurface()

                // GlassButtonStyle example
                Button("Glass Button") {}
                    .font(AppFont.buttonLabel())
                    .foregroundStyle(Color.Nomad.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .buttonStyle(GlassButtonStyle())

                // FloatingPillSurface example
                Text("Journey Pill")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.Nomad.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .floatingPillSurface()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
            .panelGlassSurface()
        }
    }
}
#endif
