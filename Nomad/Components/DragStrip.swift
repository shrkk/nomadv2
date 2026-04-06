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
        VStack(spacing: 0) {
            // 1pt amber top border
            Rectangle()
                .fill(Color.Nomad.amber.opacity(0.3))
                .frame(height: 1)

            ZStack {
                // Cream panel background — matches the sheet surface
                Rectangle()
                    .fill(Color.Nomad.cream)

                // Amber capsule handle — 8pt from top, centered horizontally
                Capsule()
                    .fill(Color.Nomad.amber.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(height: 43) // 44pt total with the 1pt border above
        }
        .frame(height: 44)
        .contentShape(Rectangle()) // Full 44pt touch target
        .onTapGesture { onTap() }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    // Any upward drag (negative vertical translation) opens the sheet
                    if value.translation.height < -10 {
                        onTap()
                    }
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
