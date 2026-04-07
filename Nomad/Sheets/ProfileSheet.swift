import SwiftUI

// MARK: - ProfileSheet
//
// Primary bottom sheet — slides up from GlobeView when a pinpoint is tapped.
// Contains a list of stub trip cards and hosts the NESTED second sheet (TripDetailSheet).
//
// INFRA-02 spike: The second sheet (.sheet(isPresented: $showTripDetail)) is attached
// INSIDE this view's body — NOT alongside GlobeView's .sheet(). This is the only pattern
// that avoids cascading dismissal (dismissing TripDetailSheet leaves ProfileSheet visible).
//
// Design: Panel gradient (D-07), Playfair Display titles, Inter body (D-08).

struct ProfileSheet: View {
    let selectedTrip: GlobePinpoint.StubTrip?
    let trips: [GlobePinpoint.StubTrip]

    @State private var showTripDetail = false
    @State private var detailTrip: GlobePinpoint.StubTrip? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header per UI-SPEC Copywriting Contract
            Text("Your Journeys")
                .font(AppFont.title())  // 28pt Playfair Display Semibold
                .foregroundStyle(Color.Nomad.amber)
                .padding(.horizontal, 16)
                .padding(.top, 24)

            // Hardcoded country count per UI-SPEC Copywriting Contract
            Text("5 countries visited")
                .font(AppFont.caption())  // 13pt Inter Regular
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            // Trip card list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(trips) { trip in
                        TripCard(trip: trip)
                            .onTapGesture {
                                detailTrip = trip
                                showTripDetail = true
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelGradient()  // Warm amber-to-cream gradient + grain per D-07
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // CRITICAL (INFRA-02): Second sheet is NESTED INSIDE ProfileSheet body.
        // Attaching .sheet() here (on the outermost view of ProfileSheet) ensures
        // SwiftUI treats TripDetailSheet as a child of ProfileSheet's sheet slot,
        // not a sibling of GlobeView's sheet slot.
        // Result: dismissing TripDetailSheet does NOT auto-dismiss ProfileSheet.
        .sheet(isPresented: $showTripDetail) {
            if let stub = detailTrip {
                // Convert stub to TripDocument for TripDetailSheet
                TripDetailSheet(trip: TripDocument(
                    id: stub.id,
                    cityName: stub.cityName,
                    startDate: Date(),
                    endDate: Date(),
                    stepCount: 0,
                    distanceMeters: 0,
                    routePreview: [[stub.latitude, stub.longitude]],
                    visitedCountryCodes: [stub.countryCode],
                    placeCounts: [:]
                ))
            }
        }
    }
}

// MARK: - Trip Card Component

struct TripCard: View {
    let trip: GlobePinpoint.StubTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.cityName + ", " + countryName(for: trip.countryCode))
                .font(AppFont.subheading())  // 20pt Playfair Display Regular
                .foregroundStyle(Color.Nomad.globeBackground)
            Text(trip.dateLabel)
                .font(AppFont.caption())  // 13pt Inter Regular
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.Nomad.warmCard)  // #F5F0E8
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func countryName(for code: String) -> String {
        // STUB: Phase 1 hardcoded mapping
        let map = ["JP": "Japan", "FR": "France", "KE": "Kenya", "AU": "Australia", "BR": "Brazil"]
        return map[code] ?? code
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.Nomad.globeBackground.ignoresSafeArea()
        Text("Globe behind sheet")
            .foregroundStyle(Color.Nomad.cream)
    }
    .sheet(isPresented: .constant(true)) {
        ProfileSheet(
            selectedTrip: GlobePinpoint.StubTrip.stubTrips.first,
            trips: GlobePinpoint.StubTrip.stubTrips
        )
    }
}
#endif
