import SwiftUI
import MapKit
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

// MARK: - TripDetailSheet
//
// Full trip detail view — slides up over ProfileSheet when a trip card is tapped.
// DETAIL-01: MapKit route map with GPS polyline + numbered place pins.
// DETAIL-02: Stats row with steps, distance, duration, places, top category.
// DETAIL-03: Photo gallery with PHAsset thumbnails matched by date + GPS bounding box.
// DETAIL-04: Nil-location photos included via date-range-only fallback.
// DETAIL-05: City name displayed as trip header.
// T-03-13: Route fetch scoped to Auth.auth().currentUser?.uid.

// MARK: - TimestampedCoordinate

private struct TimestampedCoordinate {
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
}

// MARK: - TripDetailSheet

struct TripDetailSheet: View {
    let trip: TripDocument

    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var timedCoordinates: [TimestampedCoordinate] = []
    @State private var isLoadingRoute = true
    @State private var routeFetchError = false

    // Pause-based stops: locations where user dwelled >= 90s within 40m radius
    private var visitedPlaces: [VisitedPlace] {
        let stops = detectPauseStops(from: timedCoordinates)
        return stops.enumerated().map { VisitedPlace(coordinate: $1, index: $0 + 1) }
    }

    private var boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        computeBoundingBox(from: routeCoordinates)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Header — DETAIL-05: city name + Open in Maps
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(trip.cityName)
                            .font(AppFont.title())       // 28pt Playfair Display SemiBold
                            .foregroundStyle(Color.Nomad.textPrimary)

                        Text(formattedDateRange())
                            .font(AppFont.body())        // 16pt Inter Regular
                            .foregroundStyle(Color.Nomad.textSecondary)
                    }

                    Spacer()

                    Button {
                        openInMaps()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "map")
                                .font(.system(size: 13, weight: .medium))
                            Text("Maps")
                                .font(AppFont.caption())
                        }
                        .foregroundStyle(Color.Nomad.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.35))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 16)

                // MARK: Map — DETAIL-01
                TripRouteMapContainer(
                    routeCoordinates: routeCoordinates,
                    places: visitedPlaces,
                    isLoading: isLoadingRoute
                )
                .padding(.horizontal, 16)

                if routeFetchError {
                    Text("Could not load route. Pull down to retry.")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                }

                // MARK: Stats Row — DETAIL-02
                statsRow
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // MARK: Photo Gallery — DETAIL-03, DETAIL-04
                PhotoGalleryStrip(
                    startDate: trip.startDate,
                    endDate: trip.endDate,
                    boundingBox: boundingBox
                )
                .padding(.top, 24)

                Spacer(minLength: 32)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .panelGradient()
        .presentationBackground(Color.Nomad.panelBlack)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await fetchRoutePoints()
        }
    }

    // MARK: - Pause Detection
    //
    // Scans timestamped GPS points for dwell periods: consecutive points that stay
    // within `radiusMeters` of a cluster anchor for at least `minDuration` seconds.
    // Each qualifying dwell emits one stop at the centroid of the cluster.

    private func detectPauseStops(
        from points: [TimestampedCoordinate],
        radiusMeters: Double = 40,
        minDuration: TimeInterval = 90
    ) -> [CLLocationCoordinate2D] {
        guard points.count > 1 else { return [] }

        var stops: [CLLocationCoordinate2D] = []
        var clusterStart = 0

        for i in 1..<points.count {
            let anchor = CLLocation(
                latitude: points[clusterStart].coordinate.latitude,
                longitude: points[clusterStart].coordinate.longitude
            )
            let current = CLLocation(
                latitude: points[i].coordinate.latitude,
                longitude: points[i].coordinate.longitude
            )

            if anchor.distance(from: current) > radiusMeters {
                // User moved out of cluster — check if dwell was long enough
                let duration = points[i - 1].timestamp.timeIntervalSince(points[clusterStart].timestamp)
                if duration >= minDuration {
                    stops.append(centroid(of: Array(points[clusterStart..<i])))
                }
                clusterStart = i
            }
        }

        // Check the final cluster
        if let last = points.last {
            let duration = last.timestamp.timeIntervalSince(points[clusterStart].timestamp)
            if duration >= minDuration {
                stops.append(centroid(of: Array(points[clusterStart...])))
            }
        }

        return stops
    }

    private func centroid(of points: [TimestampedCoordinate]) -> CLLocationCoordinate2D {
        let lat = points.map(\.coordinate.latitude).reduce(0, +) / Double(points.count)
        let lon = points.map(\.coordinate.longitude).reduce(0, +) / Double(points.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Open in Apple Maps

    private func openInMaps() {
        let coord = routeCoordinates.first
            ?? CLLocationCoordinate2D(
                latitude: trip.routePreview.first?[0] ?? 0,
                longitude: trip.routePreview.first?[1] ?? 0
            )
        let placemark = MKPlacemark(coordinate: coord)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = trip.cityName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coord),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(
                latitudeDelta: 0.05,
                longitudeDelta: 0.05
            ))
        ])
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: formatSteps(trip.stepCount), label: "Steps")
            Divider().frame(height: 32)
            statCell(value: formatDistance(trip.distanceMeters), label: "Distance")
            Divider().frame(height: 32)
            statCell(value: formatDuration(), label: "Duration")
            Divider().frame(height: 32)
            statCell(value: formatPlaces(), label: "Stops")
            Divider().frame(height: 32)
            topCategoryCell()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .innerCardSurface()
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.body())    // 16pt Inter Regular
                .foregroundStyle(Color.Nomad.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(AppFont.caption()) // 13pt Inter Regular
                .foregroundStyle(Color.Nomad.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func topCategoryCell() -> some View {
        let (symbol, name) = topCategoryInfo()
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(Color.Nomad.accent)
                .font(.system(size: 14, weight: .regular))
            Text(name)
                .font(AppFont.caption())
                .foregroundStyle(Color.Nomad.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Route Fetch (T-03-13: scoped to current user UID)

    private func fetchRoutePoints() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoadingRoute = false
            return
        }
        do {
            let snapshot = try await FirestoreSchema.routePointsCollection(uid, tripId: trip.id)
                .order(by: "timestamp")
                .getDocuments()
            let timed = snapshot.documents.compactMap { doc -> TimestampedCoordinate? in
                let data = doc.data()
                guard let lat = data["latitude"] as? Double,
                      let lon = data["longitude"] as? Double,
                      let ts = data["timestamp"] as? Timestamp else { return nil }
                return TimestampedCoordinate(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    timestamp: ts.dateValue()
                )
            }
            timedCoordinates = timed
            routeCoordinates = timed.map(\.coordinate)
        } catch {
            print("[TripDetail] Route fetch error: \(error)")
            routeFetchError = true
        }
        isLoadingRoute = false
    }

    // MARK: - Helpers

    private func computeBoundingBox(from coords: [CLLocationCoordinate2D])
        -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        guard !coords.isEmpty else { return nil }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        // Add ~1km padding to catch nearby photos
        let padding = 0.01
        return (
            minLat: (lats.min() ?? 0) - padding,
            maxLat: (lats.max() ?? 0) + padding,
            minLon: (lons.min() ?? 0) - padding,
            maxLon: (lons.max() ?? 0) + padding
        )
    }

    private func formattedDateRange() -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.month, .day, .year], from: trip.startDate)
        let endComponents = calendar.dateComponents([.month, .day, .year], from: trip.endDate)

        if startComponents.month == endComponents.month &&
           startComponents.year == endComponents.year {
            // Same month: "March 12 - 14, 2026"
            formatter.dateFormat = "MMMM d"
            let start = formatter.string(from: trip.startDate)
            formatter.dateFormat = "d, yyyy"
            let end = formatter.string(from: trip.endDate)
            return "\(start) - \(end)"
        } else {
            // Different months: "March 12 - April 3, 2026"
            formatter.dateFormat = "MMMM d"
            let start = formatter.string(from: trip.startDate)
            formatter.dateFormat = "MMMM d, yyyy"
            let end = formatter.string(from: trip.endDate)
            return "\(start) - \(end)"
        }
    }

    private func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    private func formatDistance(_ meters: Double) -> String {
        String(format: "%.1f km", meters / 1000)
    }

    private func formatDuration() -> String {
        let interval = trip.endDate.timeIntervalSince(trip.startDate)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatPlaces() -> String {
        let count = trip.placeCounts.values.reduce(0, +)
        return "\(count)"
    }

    private func topCategoryInfo() -> (symbol: String, name: String) {
        guard let topKey = trip.placeCounts.max(by: { $0.value < $1.value })?.key else {
            return ("mappin", "Places")
        }
        switch topKey.lowercased() {
        case "food":      return ("fork.knife",        "Food")
        case "culture":   return ("building.columns",  "Culture")
        case "nature":    return ("leaf",               "Nature")
        case "nightlife": return ("moon.stars",         "Nightlife")
        case "wellness":  return ("heart",              "Wellness")
        case "local":     return ("house",              "Local")
        default:          return ("mappin",             topKey.capitalized)
        }
    }
}

#if DEBUG
private let previewTrip = TripDocument(
    id: "preview-tokyo",
    cityName: "Tokyo",
    startDate: Calendar.current.date(byAdding: .day, value: -32, to: Date()) ?? Date(),
    endDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
    stepCount: 12450,
    distanceMeters: 8300,
    routePreview: [[35.6762, 139.6503], [35.6895, 139.6917]],
    visitedCountryCodes: ["JP"],
    placeCounts: ["food": 3, "culture": 2, "local": 1]
)

#Preview {
    TripDetailSheet(trip: previewTrip)
}
#endif
