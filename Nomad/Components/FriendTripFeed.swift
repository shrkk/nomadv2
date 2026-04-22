import SwiftUI
@preconcurrency import MapKit
import CoreLocation

// MARK: - FriendTripPost
//
// A single trip logged by a friend, rendered as a post in the home feed.
// Holds the author's public handle + a gradient-avatar hue, plus the trip
// document itself (source of the map route, city name, and timestamps).

struct FriendTripPost: Identifiable {
    let id: String
    let authorHandle: String
    let authorAvatarHue: Double  // 0-360, drives the avatar gradient
    let trip: TripDocument

    var postedAt: Date { trip.startDate }
}

// MARK: - FriendTripFeed
//
// Renders the "recent trips" section of the home panel. Sorts posts
// chronologically (most recent first). If there are no friend posts,
// shows an empty state prompting the user to add friends.

struct FriendTripFeed: View {
    let posts: [FriendTripPost]

    private var sortedPosts: [FriendTripPost] {
        posts.sorted { $0.postedAt > $1.postedAt }
    }

    var body: some View {
        VStack(spacing: 14) {
            divider

            if sortedPosts.isEmpty {
                emptyState
            } else {
                ForEach(sortedPosts) { post in
                    FriendTripFeedCard(post: post)
                }
            }
        }
    }

    private var divider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.Nomad.surfaceBorder.opacity(0.12))
                .frame(height: 1)
            Text("RECENT TRIPS")
                .font(.custom("CalSans-Regular", size: 12))
                .tracking(1.6)
                .foregroundStyle(Color.Nomad.textSecondary)
            Rectangle()
                .fill(Color.Nomad.surfaceBorder.opacity(0.12))
                .frame(height: 1)
        }
    }

    private var emptyState: some View {
        Text("Add some new friends to see their trips.")
            .font(.custom("CalSans-Regular", size: 15))
            .foregroundStyle(Color.Nomad.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
    }
}

// MARK: - FriendTripFeedCard
//
// Individual feed item. Structure mirrors the design:
//   • Avatar + handle floating above the map (no pill container)
//   • Large rounded map hero (cyan route polyline over standard map)
//   • Date pill top-left inside the map
//   • Floating share + heart pill overlapping the bottom-right of the map
//   • Trip title below in the display font

struct FriendTripFeedCard: View {
    let post: FriendTripPost

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            usernameRow

            mapHero

            Text(post.trip.cityName)
                .font(.custom("CalSans-Regular", size: 22))
                .foregroundStyle(Color.Nomad.textPrimary)
                .lineLimit(2)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Username row

    private var usernameRow: some View {
        HStack(spacing: 10) {
            avatar
            Text("@\(post.authorHandle)")
                .font(.custom("CalSans-Regular", size: 16))
                .foregroundStyle(Color.Nomad.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private var avatar: some View {
        let baseHue = post.authorAvatarHue / 360.0
        return Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: baseHue, saturation: 0.32, brightness: 0.75),
                        Color(hue: baseHue, saturation: 0.28, brightness: 0.42)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: 32, height: 32)
            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Map hero

    private var mapHero: some View {
        FriendTripRouteMap(routePreview: post.trip.routePreview)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.Nomad.surfaceBorder.opacity(0.18), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) { datePill.padding(14) }
            .overlay(alignment: .bottomTrailing) { actionPill.padding(10) }
    }

    private var datePill: some View {
        Text(Self.dateFormatter.string(from: post.trip.startDate))
            .font(.custom("CalSans-Regular", size: 13))
            .foregroundStyle(Color(hex: 0x0F0F28).opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .background(Color.white.opacity(0.55), in: Capsule())
    }

    private var actionPill: some View {
        HStack(spacing: 4) {
            actionIcon(systemName: "paperplane.fill", filled: false)
            actionIcon(systemName: "heart.fill", filled: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.Nomad.globeBackground.opacity(0.75))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func actionIcon(systemName: String, filled: Bool) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(filled ? Color.Nomad.textPrimary : Color.Nomad.textSecondary)
            .frame(width: 26, height: 26)
    }
}

// MARK: - FriendTripRouteMap
//
// Non-interactive MapKit view that renders a trip's route preview as a
// cyan polyline, auto-fit to its bounding rect. Used as the map hero
// inside FriendTripFeedCard.

struct FriendTripRouteMap: UIViewRepresentable {
    let routePreview: [[Double]]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.mapType = .standard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsUserLocation = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coords = routePreview.compactMap { pair -> CLLocationCoordinate2D? in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
        guard coords.count >= 2 else {
            if let first = coords.first {
                mapView.setCamera(
                    MKMapCamera(lookingAtCenter: first, fromDistance: 4_000, pitch: 0, heading: 0),
                    animated: false
                )
            }
            return
        }
        guard !context.coordinator.routeDrawn else { return }
        context.coordinator.routeDrawn = true

        var coordsCopy = coords
        let polyline = MKPolyline(coordinates: &coordsCopy, count: coordsCopy.count)
        mapView.addOverlay(polyline)

        let padding = UIEdgeInsets(top: 36, left: 24, bottom: 36, right: 24)
        mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: padding, animated: false)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var routeDrawn = false

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(hex: 0x5EE0DD)
                renderer.lineWidth = 3.5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Empty") {
    ScrollView {
        FriendTripFeed(posts: [])
            .padding(.horizontal, 20)
    }
    .background(Color.Nomad.panelBlack.ignoresSafeArea())
}

#Preview("With posts") {
    let posts = [
        FriendTripPost(
            id: "maya-walk",
            authorHandle: "maya.v",
            authorAvatarHue: 260,
            trip: TripDocument(
                id: "t1", cityName: "walk to denny",
                startDate: Date(timeIntervalSinceNow: -86_400 * 3),
                endDate: Date(timeIntervalSinceNow: -86_400 * 3 + 7_200),
                stepCount: 8_200, distanceMeters: 5_400,
                routePreview: [
                    [47.6205, -122.3493], [47.6150, -122.3400],
                    [47.6100, -122.3310], [47.6062, -122.3321],
                    [47.6000, -122.3420]
                ],
                visitedCountryCodes: ["US"], placeCounts: [:]
            )
        ),
        FriendTripPost(
            id: "leo-ferry",
            authorHandle: "leo.b",
            authorAvatarHue: 20,
            trip: TripDocument(
                id: "t2", cityName: "ferry loop",
                startDate: Date(timeIntervalSinceNow: -86_400 * 7),
                endDate: Date(timeIntervalSinceNow: -86_400 * 7 + 5_400),
                stepCount: 6_100, distanceMeters: 4_200,
                routePreview: [
                    [47.6020, -122.3380], [47.6090, -122.3500],
                    [47.6130, -122.3590], [47.6200, -122.3480]
                ],
                visitedCountryCodes: ["US"], placeCounts: [:]
            )
        )
    ]
    return ScrollView {
        FriendTripFeed(posts: posts)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
    }
    .background(Color.Nomad.panelBlack.ignoresSafeArea())
}
#endif
