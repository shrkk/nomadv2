import SwiftUI

// MARK: - JourneyPill
//
// Floating pill shown at bottom of globe when ProfileSheet is dismissed.
// Provides quick access to journeys list and trip recording without blocking
// globe interaction — only the pill itself captures touches.

struct JourneyPill: View {
    let onOpenJourneys: () -> Void
    let onStartTrip: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Profile / Journeys button
            Button(action: onOpenJourneys) {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.Nomad.globeBackground)

                    Text("Journeys")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.globeBackground)
                }
                .padding(.leading, 16)
                .padding(.trailing, 12)
            }

            // Divider
            Rectangle()
                .fill(Color.Nomad.globeBackground.opacity(0.2))
                .frame(width: 1, height: 24)

            // Log trip button
            Button(action: onStartTrip) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.Nomad.amber)
                    .padding(.leading, 12)
                    .padding(.trailing, 16)
            }
        }
        .frame(height: 48)
        .background(Color.Nomad.warmCard)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    if value.translation.height < -10 { onOpenJourneys() }
                }
        )
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            JourneyPill(
                onOpenJourneys: { print("open") },
                onStartTrip: { print("start") }
            )
            .padding(.bottom, 24)
        }
    }
}
#endif
