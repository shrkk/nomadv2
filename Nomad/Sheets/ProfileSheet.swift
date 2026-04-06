import SwiftUI

// MARK: - ProfileSheet
//
// Primary bottom sheet — slides up from GlobeView when DragStrip is tapped or
// a pinpoint is selected. Contains real trip data as route preview cards and
// hosts the NESTED second sheet (TripDetailSheet).
//
// INFRA-02 spike: The second sheet (.sheet(isPresented: $showTripDetail)) is attached
// INSIDE this view's body — NOT alongside GlobeView's .sheet(). This is the only pattern
// that avoids cascading dismissal (dismissing TripDetailSheet leaves ProfileSheet visible).
//
// Design: Panel gradient (D-07), Playfair Display titles, Inter body (D-08).
// Source: PANEL-01 through PANEL-06, UI-SPEC Profile Sheet + Trip Preview Card.

struct ProfileSheet: View {
    let trips: [TripDocument]
    let scrollToTripId: String?
    let onStartTrip: (() -> Void)?

    @State private var showTripDetail = false
    @State private var detailTrip: TripDocument? = nil
    @State private var showPassport = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    private static let stepsFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: Header
            HStack(alignment: .center) {
                // Profile button (left) — opens Traveler Passport (PANEL-06)
                Button {
                    showPassport = true
                } label: {
                    Image(systemName: "person.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.Nomad.globeBackground)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // Title
                Text("Your Journeys")
                    .font(AppFont.title())
                    .foregroundStyle(Color.Nomad.globeBackground)

                Spacer()

                // "+" button (right) — start new trip (PANEL-05; recording wired in Plan 03)
                Button {
                    onStartTrip?()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.Nomad.amber)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // MARK: Trip list or empty state
            if trips.isEmpty {
                // Empty state per UI-SPEC Copywriting
                VStack(spacing: 8) {
                    Text("No trips yet.")
                        .font(AppFont.subheading())
                        .foregroundStyle(Color.Nomad.globeBackground)
                    Text("Tap + to start recording your first trip.")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.globeBackground.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(trips) { trip in
                                TripPreviewCard(
                                    trip: trip,
                                    dateFormatter: Self.dateFormatter,
                                    stepsFormatter: Self.stepsFormatter
                                )
                                .id(trip.id)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        detailTrip = trip
                                        showTripDetail = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .onChange(of: scrollToTripId) { _, newId in
                        guard let id = newId else { return }
                        withAnimation {
                            proxy.scrollTo(id, anchor: .top)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panelGradient()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // CRITICAL (INFRA-02): TripDetailSheet nested inside ProfileSheet body.
        // Dismissing TripDetailSheet does NOT auto-dismiss ProfileSheet.
        .sheet(isPresented: $showTripDetail) {
            if let trip = detailTrip {
                TripDetailSheet(trip: trip)
            }
        }
        // Traveler Passport stub (PANEL-06)
        .sheet(isPresented: $showPassport) {
            TravelerPassportStub()
        }
    }
}

// MARK: - Trip Preview Card

struct TripPreviewCard: View {
    let trip: TripDocument
    let dateFormatter: DateFormatter
    let stepsFormatter: NumberFormatter

    var body: some View {
        HStack(spacing: 16) {
            // Route strip: 120×48pt, globe-dark background with amber path
            ZStack {
                Color.Nomad.globeBackground.opacity(0.9)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                GeometryReader { geo in
                    RoutePreviewPath(
                        routePreview: trip.routePreview,
                        size: geo.size
                    )
                }
                .padding(4)
            }
            .frame(width: 120, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Trip info
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.cityName)
                    .font(AppFont.subheading())
                    .foregroundStyle(Color.Nomad.globeBackground)
                    .lineLimit(1)

                Text(dateFormatter.string(from: trip.startDate))
                    .font(AppFont.caption())
                    .foregroundStyle(Color.Nomad.globeBackground.opacity(0.6))

                Text(distanceStepsLabel)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.Nomad.globeBackground.opacity(0.6))
            }

            Spacer(minLength: 0)
        }
        .frame(height: 96)
        .padding(16)
        .background(Color.Nomad.warmCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var distanceStepsLabel: String {
        let km = String(format: "%.1f km", trip.distanceMeters / 1000)
        let steps = stepsFormatter.string(from: NSNumber(value: trip.stepCount)) ?? "\(trip.stepCount)"
        return "\(km) . \(steps) steps"
    }
}

#if DEBUG
private let previewTrips: [TripDocument] = [
    TripDocument(
        id: "preview-tokyo",
        cityName: "Tokyo",
        startDate: Date(timeIntervalSinceNow: -86400 * 30),
        endDate: Date(timeIntervalSinceNow: -86400 * 28),
        stepCount: 12450,
        distanceMeters: 8300,
        routePreview: [
            [35.6762, 139.6503],
            [35.6895, 139.6917],
            [35.7100, 139.8107],
            [35.6584, 139.7454]
        ],
        visitedCountryCodes: ["JP"],
        placeCounts: ["food": 3, "culture": 2]
    ),
    TripDocument(
        id: "preview-paris",
        cityName: "Paris",
        startDate: Date(timeIntervalSinceNow: -86400 * 90),
        endDate: Date(timeIntervalSinceNow: -86400 * 88),
        stepCount: 9800,
        distanceMeters: 6200,
        routePreview: [
            [48.8566, 2.3522],
            [48.8630, 2.3387],
            [48.8738, 2.2950]
        ],
        visitedCountryCodes: ["FR"],
        placeCounts: ["culture": 4, "food": 2]
    )
]

#Preview("With trips") {
    ZStack {
        Color.Nomad.globeBackground.ignoresSafeArea()
    }
    .sheet(isPresented: .constant(true)) {
        ProfileSheet(
            trips: previewTrips,
            scrollToTripId: nil,
            onStartTrip: nil
        )
    }
}

#Preview("Empty state") {
    ZStack {
        Color.Nomad.globeBackground.ignoresSafeArea()
    }
    .sheet(isPresented: .constant(true)) {
        ProfileSheet(
            trips: [],
            scrollToTripId: nil,
            onStartTrip: nil
        )
    }
}
#endif
