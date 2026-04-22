import SwiftUI

// MARK: - ProfileSheet
//
// Persistent bottom panel with three snap points: peek (handle visible),
// half screen, and full screen. Contains two tabs: Passport and Journeys.
// Replaces the old modal sheet + DragStrip + JourneyPill pattern.

struct ProfileSheet: View {
    let trips: [TripDocument]
    let scrollToTripId: String?
    let onStartTrip: (() -> Void)?
    var onDeleteTrip: ((TripDocument) -> Void)? = nil
    var countries: [CountryFeature] = []
    var homeCityName: String? = nil
    var friendPosts: [FriendTripPost] = []

    @State private var showTripDetail = false
    @State private var detailTrip: TripDocument? = nil
    @State private var selectedDetent: PresentationDetent = .height(96)
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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            handleBar
                .padding(.top, 8)
                .padding(.bottom, 4)

            HomeFeedView(friendPosts: friendPosts, onProfileTap: { showPassport = true })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.Nomad.panelBlack.ignoresSafeArea())
        .presentationDetents([.height(96), .medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
        .presentationBackground(Color.Nomad.panelBlack)
        .presentationBackgroundInteraction(.enabled(upThrough: .height(96)))
        .sheet(isPresented: $showTripDetail) {
            if let trip = detailTrip {
                TripDetailSheet(trip: trip)
            }
        }
        .sheet(isPresented: $showPassport) {
            TravelerPassport(
                trips: trips,
                visitedCountryCodes: Array(Set(trips.flatMap(\.visitedCountryCodes))),
                countries: countries,
                homeCityName: homeCityName
            )
        }
    }

    // MARK: - Handle Bar

    private var handleBar: some View {
        Capsule()
            .fill(Color.Nomad.surfaceBorder.opacity(0.30))
            .frame(width: 36, height: 4)
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
    private let actionWidth: CGFloat = 132

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 12) {
                Button {
                    resetSwipe()
                    onShare?()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.Nomad.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(Color.Nomad.panelBlack)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.Nomad.surfaceBorder.opacity(0.20), lineWidth: 1))
                }

                Button {
                    resetSwipe()
                    onDelete?()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.Nomad.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
            .padding(.trailing, 8)
            .opacity(swipeOffset < 0 ? 1 : 0)

            cardContent
                .offset(x: swipeOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let dx = value.translation.width
                            if dx < 0 {
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
                .fill(Color.Nomad.globeBackground.opacity(0.50))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.Nomad.surfaceBorder.opacity(0.12), lineWidth: 1)
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
        id: "preview-tokyo", cityName: "Tokyo",
        startDate: Date(timeIntervalSinceNow: -86400 * 30),
        endDate: Date(timeIntervalSinceNow: -86400 * 28),
        stepCount: 12450, distanceMeters: 8300,
        routePreview: [[35.6762, 139.6503], [35.6895, 139.6917], [35.7100, 139.8107]],
        visitedCountryCodes: ["JP"], placeCounts: ["food": 3, "culture": 2]
    ),
    TripDocument(
        id: "preview-paris", cityName: "Paris",
        startDate: Date(timeIntervalSinceNow: -86400 * 90),
        endDate: Date(timeIntervalSinceNow: -86400 * 88),
        stepCount: 9800, distanceMeters: 6200,
        routePreview: [[48.8566, 2.3522], [48.8630, 2.3387], [48.8738, 2.2950]],
        visitedCountryCodes: ["FR"], placeCounts: ["culture": 4, "food": 2]
    )
]

#Preview("With trips") {
    Color.Nomad.globeBackground.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ProfileSheet(trips: previewTrips, scrollToTripId: nil, onStartTrip: nil)
        }
}

#Preview("Empty state") {
    Color.Nomad.globeBackground.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ProfileSheet(trips: [], scrollToTripId: nil, onStartTrip: nil)
        }
}
#endif
