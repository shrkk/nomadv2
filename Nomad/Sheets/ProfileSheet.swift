import SwiftUI

// MARK: - ProfileSheet
//
// Primary bottom sheet — slides up from GlobeView when DragStrip is tapped/dragged or
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
    var onDeleteTrip: ((TripDocument) -> Void)? = nil
    var homeCityName: String? = nil

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
                Button {
                    showPassport = true
                } label: {
                    Image(systemName: "person.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.Nomad.textPrimary)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Text("Your Journeys")
                    .font(AppFont.title())
                    .foregroundStyle(Color.Nomad.textPrimary)

                Spacer()

                Button {
                    onStartTrip?()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.Nomad.accent)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 44)
            .padding(.bottom, homeCityName != nil ? 8 : 16)

            // MARK: Home city
            if let homeCityName {
                HStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Nomad.textSecondary)
                    Text(homeCityName)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
            }

            // MARK: Trip list or empty state
            if trips.isEmpty {
                VStack(spacing: 8) {
                    Text("No trips yet.")
                        .font(AppFont.subheading())
                        .foregroundStyle(Color.Nomad.textPrimary)
                    Text("Tap + to start recording your first trip.")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(trips) { trip in
                                TripPreviewCard(
                                    trip: trip,
                                    dateFormatter: Self.dateFormatter,
                                    stepsFormatter: Self.stepsFormatter,
                                    onTap: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                            detailTrip = trip
                                            showTripDetail = true
                                        }
                                    },
                                    onDelete: onDeleteTrip.map { cb in { cb(trip) } },
                                    onShare: { shareTrip(trip) }
                                )
                                .id(trip.id)
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
        .ignoresSafeArea(edges: .bottom)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.Nomad.panelBlack)
        // CRITICAL (INFRA-02): TripDetailSheet nested inside ProfileSheet body.
        .sheet(isPresented: $showTripDetail) {
            if let trip = detailTrip {
                TripDetailSheet(trip: trip)
            }
        }
        .sheet(isPresented: $showPassport) {
            TravelerPassportStub()
        }
    }

    private func shareTrip(_ trip: TripDocument) {
        let text = "\(trip.cityName) — \(Self.dateFormatter.string(from: trip.startDate))"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - Trip Preview Card

struct TripPreviewCard: View {
    let trip: TripDocument
    let dateFormatter: DateFormatter
    let stepsFormatter: NumberFormatter
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil

    @State private var swipeOffset: CGFloat = 0
    private let actionWidth: CGFloat = 132 // 2 × 66pt action buttons

    var body: some View {
        ZStack(alignment: .trailing) {
            // MARK: Action buttons revealed on swipe
            HStack(spacing: 12) {
                // Share
                Button {
                    resetSwipe()
                    onShare?()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.Nomad.panelBlack)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                }

                // Delete
                Button {
                    resetSwipe()
                    onDelete?()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
            .padding(.trailing, 8)
            .opacity(swipeOffset < 0 ? 1 : 0)

            // MARK: Card content (slides left on swipe)
            cardContent
                .offset(x: swipeOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let dx = value.translation.width
                            if dx < 0 {
                                // Resist past full reveal with rubber-band
                                swipeOffset = max(dx, -actionWidth - 20) * (abs(dx) > actionWidth ? 0.3 : 1)
                            } else if swipeOffset < 0 {
                                swipeOffset = min(0, swipeOffset + dx)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                swipeOffset = value.translation.width < -actionWidth / 2 ? -actionWidth : 0
                            }
                        }
                )
                .onTapGesture {
                    if swipeOffset < 0 {
                        resetSwipe()
                    } else {
                        onTap()
                    }
                }
        }
        .frame(height: 96)
    }

    private var cardContent: some View {
        HStack(spacing: 16) {
            // Route strip — transparent background so card colour shows through
            ZStack {
                Color.clear
                GeometryReader { geo in
                    RoutePreviewPath(
                        routePreview: trip.routePreview,
                        size: geo.size
                    )
                }
                .padding(4)
            }
            .frame(width: 120, height: 64)
            .background(Color.Nomad.globeBackground.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.cityName)
                    .font(AppFont.subheading())
                    .foregroundStyle(Color.Nomad.textPrimary)
                    .lineLimit(1)

                Text(dateFormatter.string(from: trip.startDate))
                    .font(AppFont.caption())
                    .foregroundStyle(Color.Nomad.textSecondary)

                Text(distanceStepsLabel)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.Nomad.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 96)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var distanceStepsLabel: String {
        let km = String(format: "%.1f km", trip.distanceMeters / 1000)
        let steps = stepsFormatter.string(from: NSNumber(value: trip.stepCount)) ?? "\(trip.stepCount)"
        return "\(km) · \(steps) steps"
    }

    private func resetSwipe() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            swipeOffset = 0
        }
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
