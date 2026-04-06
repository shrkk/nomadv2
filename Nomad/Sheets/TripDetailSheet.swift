import SwiftUI
import MapKit
import CoreLocation
import FirebaseAuth

// MARK: - TripDetailSheet
//
// Full trip detail view — slides up over ProfileSheet when a trip card is tapped.
// DETAIL-01: MapKit route map with GPS polyline + numbered place pins.
// DETAIL-02: Stats row with steps, distance, duration, places, top category.
// DETAIL-03: Photo gallery with PHAsset thumbnails matched by date + GPS bounding box.
// DETAIL-04: Nil-location photos included via date-range-only fallback.
// DETAIL-05: City name displayed as trip header.
// T-03-13: Route fetch scoped to Auth.auth().currentUser?.uid.

struct TripDetailSheet: View {
    let trip: TripDocument

    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var isLoadingRoute = true
    @State private var routeFetchError = false

    // Derived visited places for numbered pins — sampled from full route
    private var visitedPlaces: [VisitedPlace] {
        guard !routeCoordinates.isEmpty else { return [] }
        // Sample every ~20th point matching TripService.sampleStopCoordinates pattern
        let stride = max(1, routeCoordinates.count / 20)
        return routeCoordinates.enumerated().compactMap { idx, coord in
            guard idx % stride == 0 else { return nil }
            return VisitedPlace(coordinate: coord, index: (idx / stride) + 1)
        }
    }

    private var boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        computeBoundingBox(from: routeCoordinates)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Header — DETAIL-05: city name
                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.cityName)
                        .font(AppFont.title())       // 28pt Playfair Display SemiBold
                        .foregroundStyle(Color.Nomad.globeBackground)

                    Text(formattedDateRange())
                        .font(AppFont.body())        // 16pt Inter Regular
                        .foregroundStyle(Color.Nomad.globeBackground.opacity(0.6))
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
                        .foregroundStyle(Color.Nomad.globeBackground.opacity(0.5))
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            await fetchRoutePoints()
        }
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
        .background(Color.Nomad.warmCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.body())    // 16pt Inter Regular
                .foregroundStyle(Color.Nomad.amber)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(AppFont.caption()) // 13pt Inter Regular
                .foregroundStyle(Color.Nomad.globeBackground.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func topCategoryCell() -> some View {
        let (symbol, name) = topCategoryInfo()
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(Color.Nomad.amber)
                .font(.system(size: 14, weight: .regular))
            Text(name)
                .font(AppFont.caption())
                .foregroundStyle(Color.Nomad.globeBackground.opacity(0.6))
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
            let coords = snapshot.documents.compactMap { doc -> CLLocationCoordinate2D? in
                let data = doc.data()
                guard let lat = data["latitude"] as? Double,
                      let lon = data["longitude"] as? Double else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            routeCoordinates = coords
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
