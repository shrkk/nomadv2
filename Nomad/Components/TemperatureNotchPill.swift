import SwiftUI

// MARK: - TemperatureNotchPill
//
// Displays temperature as a dark capsule pill overlay on the photo carousel.
// T-3.1-05: Only shown when a non-nil temperature string is provided.
// Per UI-SPEC: dark globeBackground pill with cream text. NOT amber.

struct TemperatureNotchPill: View {
    let temperature: String

    var body: some View {
        Text(temperature)
            .font(AppFont.caption())
            .foregroundStyle(Color.Nomad.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(Color.Nomad.globeBackground.opacity(0.9))
                    .overlay(
                        Capsule()
                            .stroke(Color.Nomad.surfaceBorder.opacity(0.20), lineWidth: 1)
                    )
            )
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        TemperatureNotchPill(temperature: "-8°C")
        TemperatureNotchPill(temperature: "22°C")
        TemperatureNotchPill(temperature: "—°C")
    }
    .padding()
    .background(Color.Nomad.panelBlack)
}
#endif
