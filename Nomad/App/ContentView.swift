import SwiftUI

// ContentView — Phase 1 stub. Validates design tokens render correctly.
// Shows font samples on a panel gradient background.
struct ContentView: View {
    var body: some View {
        ZStack {
            // Globe background color (placeholder for RealityKit globe in later plans)
            Color.Nomad.globeBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Panel stub — demonstrates PanelGradient + AppFont tokens
                VStack(alignment: .leading, spacing: 16) {
                    // Panel drag handle
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(Color.Nomad.warmCard)
                            .frame(width: 36, height: 4)
                        Spacer()
                    }
                    .padding(.top, 8)

                    Text("Your Journeys")
                        .font(AppFont.title())
                        .foregroundStyle(Color.Nomad.globeBackground)

                    Text("5 countries visited")
                        .font(AppFont.subheading())
                        .foregroundStyle(Color.Nomad.amber)

                    Text("Tap a country on the globe to explore your trips.")
                        .font(AppFont.body())
                        .foregroundStyle(Color.Nomad.globeBackground.opacity(0.7))

                    Text("Phase 1 — Design System Spike")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.globeBackground.opacity(0.4))

                    Button(action: {}) {
                        Text("Start a Trip")
                            .font(AppFont.buttonLabel())
                            .foregroundStyle(Color.Nomad.cream)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.Nomad.amber)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .panelGradient()
            }
        }
    }
}

#Preview {
    ContentView()
}
