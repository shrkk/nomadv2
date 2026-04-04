import SwiftUI

// PanelGradientModifier — canonical panel gradient for all phases.
// Warm amber (#E8A44A at 20% opacity) radiates from top-left and top-right corners,
// fading to transparent by the panel midpoint. Grain noise overlay at 8% opacity.
// Corner radius: 20pt top corners, 0pt bottom corners (extends to safe area edge).
// Source: D-07 (CONTEXT.md), UI-SPEC Panel Gradient section.
struct PanelGradientModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Color.Nomad.cream // #FAF8F4 solid base

                    // Top-left corner amber radial bleed
                    RadialGradient(
                        colors: [Color.Nomad.amber.opacity(0.20), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )

                    // Top-right corner amber radial bleed
                    RadialGradient(
                        colors: [Color.Nomad.amber.opacity(0.20), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 200
                    )

                    // Grain overlay — bundled noise PNG at 8% opacity
                    Image("grain-noise")
                        .resizable(resizingMode: .tile)
                        .opacity(0.08)
                }
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 20,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 20
                )
            )
    }
}

extension View {
    func panelGradient() -> some View {
        modifier(PanelGradientModifier())
    }
}

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
                        .fill(Color.Nomad.warmCard)
                        .frame(width: 36, height: 4)
                    Spacer()
                }
                .padding(.top, 8)
                Text("Panel Gradient Preview")
                    .font(AppFont.title())
                    .foregroundStyle(Color.Nomad.globeBackground)
                Text("Amber bleeds from top corners, grain at 8% opacity.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.Nomad.globeBackground.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
            .panelGradient()
        }
    }
}
#endif
