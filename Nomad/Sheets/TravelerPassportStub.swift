import SwiftUI

// MARK: - TravelerPassportStub
//
// Stub view for the Traveler Passport (PANEL-06).
// Presented via .sheet from ProfileSheet's profile button.
// Full implementation deferred to Phase 4.
//
// Design: panelGradient, Playfair Display subheading, .large detent.
// Copy: per UI-SPEC Copywriting — "Passport coming soon."
// Source: PANEL-06, UI-SPEC Copywriting Contract.

struct TravelerPassportStub: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Passport coming soon.")
                .font(AppFont.subheading())
                .foregroundStyle(Color.Nomad.globeBackground)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .panelGradient()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.Nomad.globeBackground.ignoresSafeArea()
    }
    .sheet(isPresented: .constant(true)) {
        TravelerPassportStub()
    }
}
#endif
