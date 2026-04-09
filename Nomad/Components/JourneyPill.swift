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
                        .foregroundStyle(Color.Nomad.textPrimary)

                    Text("Journeys")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.textPrimary)
                }
                .padding(.leading, 16)
                .padding(.trailing, 12)
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.20))
                .frame(width: 1, height: 24)

            // Log trip button
            Button(action: onStartTrip) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.Nomad.accent)
                    .padding(.leading, 12)
                    .padding(.trailing, 16)
            }
        }
        .frame(height: 48)
        .floatingPillSurface()
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
