import SwiftUI

// MARK: - ProfileSheet
//
// Primary bottom sheet — slides up from GlobeView when a pinpoint is tapped.
// Contains a list of trip cards and hosts the NESTED second sheet (TripDetailSheet).
//
// INFRA-02 spike: The second sheet (.sheet(isPresented: $showTripDetail)) is attached
// INSIDE this view's body — NOT alongside GlobeView's .sheet(). This is the only pattern
// that avoids cascading dismissal (dismissing TripDetailSheet leaves ProfileSheet visible).
//
// Design: Panel gradient (D-07), Playfair Display titles, Inter body (D-08).
// Updated in Phase 3 Plan 01: accepts TripDocument instead of StubTrip.

struct ProfileSheet: View {
    let trips: [TripDocument]
    let scrollToTripId: String?

    @State private var showTripDetail = false
    @State private var detailTrip: TripDocument? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header per UI-SPEC Copywriting Contract
            Text("Your Journeys")
                .font(AppFont.title())  // 28pt Playfair Display Semibold
                .foregroundStyle(Color.Nomad.amber)
                .padding(.horizontal, 16)
                .padding(.top, 24)

            // Live country count derived from trips
            Text("\(visitedCountryCount) \(visitedCountryCount == 1 ? "country" : "countries") visited")
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
            if let trip = detailTrip {
                TripDetailSheet(trip: trip)
            }
        }
    }

    private var visitedCountryCount: Int {
        Set(trips.flatMap(\.visitedCountryCodes)).count
    }
}

// MARK: - Trip Card Component

struct TripCard: View {
    let trip: TripDocument

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.cityName)
                .font(AppFont.subheading())  // 20pt Playfair Display Regular
                .foregroundStyle(Color.Nomad.globeBackground)
            Text(Self.dateFormatter.string(from: trip.startDate))
                .font(AppFont.caption())  // 13pt Inter Regular
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.Nomad.warmCard)  // #F5F0E8
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#if DEBUG
private let previewTrip = TripDocument(
    id: "preview-tokyo",
    cityName: "Tokyo",
    startDate: Date(timeIntervalSinceNow: -86400 * 30),
    endDate: Date(timeIntervalSinceNow: -86400 * 28),
    stepCount: 12450,
    distanceMeters: 8300,
    routePreview: [[35.6762, 139.6503]],
    visitedCountryCodes: ["JP"],
    placeCounts: ["food": 3, "culture": 2]
)

#Preview {
    ZStack {
        Color.Nomad.globeBackground.ignoresSafeArea()
        Text("Globe behind sheet")
            .foregroundStyle(Color.Nomad.cream)
    }
    .sheet(isPresented: .constant(true)) {
        ProfileSheet(
            trips: [previewTrip],
            scrollToTripId: nil
        )
    }
}
#endif
