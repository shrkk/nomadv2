import SwiftUI
import Combine

// RecordingPill — Active trip indicator shown on globe during recording.
// TRIP-04: Appears when LocationManager.isRecording == true.
// D-07: Pulsing red dot (8pt, Color.red), elapsed timer, Stop Trip button.
// D-08: Inter Semibold 16pt for button, Inter Regular 16pt for elapsed text.
// T-03-09: Pill is conditionally removed from view hierarchy (not just hidden)
// when recording stops — ensures Timer.publish is cancelled/deallocated.
// The conditional `if locationManager.isRecording` in GlobeView handles this.

struct RecordingPill: View {
    @Environment(LocationManager.self) private var locationManager
    let onStopTrip: () -> Void

    @State private var elapsedSeconds: Int = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            // Pulsing red dot — 8pt diameter, Color.red
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .modifier(PulseAnimation())

            // Elapsed time text
            Text("Recording — \(elapsedText)")
                .font(AppFont.body())  // 16pt Inter Regular
                .foregroundStyle(Color.Nomad.cream)

            // Stop Trip button
            Button(action: onStopTrip) {
                Text("Stop Trip")
                    .font(AppFont.buttonLabel())  // 16pt Inter Semibold
                    .foregroundStyle(Color.Nomad.amber)
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44) // Touch target
        .background(
            Capsule()
                .fill(.thinMaterial)
                .overlay(
                    Capsule()
                        .fill(Color.Nomad.globeBackground.opacity(0.85))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.Nomad.amber.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.Nomad.globeBackground.opacity(0.2), radius: 8, y: 4)
        .onReceive(timer) { _ in
            elapsedSeconds += 1
        }
        .onAppear {
            elapsedSeconds = 0
        }
    }

    private var elapsedText: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "0m \(s)s"
    }
}

// Pulsing animation: scale 1.0->1.4->1.0, opacity 1.0->0.6->1.0, 2-second cycle
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.4 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
