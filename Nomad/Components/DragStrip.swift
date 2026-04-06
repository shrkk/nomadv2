import SwiftUI

// MARK: - DragStrip
//
// Persistent bottom handle that anchors ProfileSheet access from the globe.
// Always visible — never hidden during recording (D-02).
//
// Visual height: 24pt. Touch area height: 44pt (extended upward per Apple HIG).
// Background: ultraThinMaterial + Nomad.globeBackground at 60% opacity.
// Top border: 1pt Nomad.amber at 30% opacity.
// Handle: Capsule 36×4pt, Nomad.amber at 40% opacity, 8pt from top.
//
// Source: D-01, D-02, UI-SPEC Drag Strip section.

struct DragStrip: View {
    let onTap: () -> Void

    var body: some View {
        ZStack {
            // Card-style background: warmCard color, rounded top corners only
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 16
            )
            .fill(Color.Nomad.warmCard)

            // Amber capsule handle — centered, 10pt from top
            Capsule()
                .fill(Color.Nomad.amber.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(height: 44)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: -4)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    if value.translation.height < -10 { onTap() }
                }
        )
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.Nomad.globeBackground.ignoresSafeArea()
        VStack {
            Spacer()
            DragStrip(onTap: { print("DragStrip tapped") })
        }
    }
}
#endif
