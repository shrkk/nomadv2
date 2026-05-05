import SwiftUI
@preconcurrency import MapKit
import CoreLocation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore
import Photos

// MARK: - TripDetailSheet
//
// Full trip detail view — slides up when a trip is tapped on the globe.
// Design: "A. Rich trip — Kyoto" layout from Trip Sheet Redesign.
// Sections: Header, Map, Stats, Category Chips, POI Timeline, Photo Grid, Share CTA.

// MARK: - TimestampedCoordinate

private struct TimestampedCoordinate {
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
}

// MARK: - DetectedStop
//
// A pause-detected stop enriched with geocoded name and dwell metadata.

private struct DetectedStop: Identifiable {
    let id: Int                             // 1-based index
    let coordinate: CLLocationCoordinate2D
    let arrivalTime: Date
    let dwellMinutes: Int
    var name: String                        // Reverse-geocoded; starts as "Loading..."
}

// MARK: - TripDetailSheet

struct TripDetailSheet: View {
    let trip: TripDocument
    var ownerUID: String? = nil

    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var timedCoordinates: [TimestampedCoordinate] = []
    @State private var isLoadingRoute = true
    @State private var routeFetchError = false
    @State private var showShareSheet = false

    // POI timeline state
    @State private var detectedStops: [DetectedStop] = []
    @State private var expandedStopId: Int? = nil

    // Photo grid state
    @State private var photoThumbnails: [(id: String, image: UIImage)] = []
    @State private var isLoadingPhotos = true
    @State private var photoPermissionDenied = false
    @State private var totalPhotoCount = 0

    private var visitedPlaces: [VisitedPlace] {
        detectedStops.map { VisitedPlace(coordinate: $0.coordinate, index: $0.id) }
    }

    private var boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        computeBoundingBox(from: routeCoordinates)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.Nomad.accent)
                                .frame(width: 6, height: 6)
                            Text(trip.visitedCountryCodes.first?.uppercased() ?? "")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(0.5)
                                .foregroundStyle(Color.Nomad.textSecondary)
                                .textCase(.uppercase)
                        }
                        Text(trip.cityName)
                            .font(.custom("CalSans-Regular", size: 30))
                            .foregroundStyle(Color.Nomad.textPrimary)
                            .lineLimit(2)
                            .padding(.top, 2)
                        Text(formattedDateRange())
                            .font(.system(size: 13))
                            .foregroundStyle(Color.Nomad.textSecondary)
                            .padding(.top, 1)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button { openInMaps() } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "map")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Maps")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color.Nomad.textPrimary)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(Color.Nomad.globeBackground.opacity(0.5))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.Nomad.surfaceBorder.opacity(0.2), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        if ownerUID == nil {
                            Button { showShareSheet = true } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Share")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(Color.Nomad.panelBlack)
                                .padding(.horizontal, 10)
                                .frame(height: 32)
                                .background(Color.Nomad.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // MARK: Map with distance badge
                ZStack(alignment: .topLeading) {
                    TripRouteMapContainer(
                        routeCoordinates: routeCoordinates,
                        places: visitedPlaces,
                        isLoading: isLoadingRoute
                    )

                    // Glass distance badge
                    HStack(spacing: 5) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.Nomad.accent)
                        Text(formatDistance(trip.distanceMeters))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.Nomad.textPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .overlay(Capsule().stroke(Color.Nomad.surfaceBorder.opacity(0.18), lineWidth: 1))
                    .clipShape(Capsule())
                    .padding(10)
                }
                .padding(.horizontal, 16)

                if routeFetchError {
                    Text("Could not load route.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Nomad.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                        .padding(.horizontal, 16)
                }

                // MARK: Horizontal Stat Cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        statCard(value: formatDistance(trip.distanceMeters), label: "Distance", unit: "km")
                        statCard(value: formatDuration(), label: "Duration")
                        statCard(value: formatSteps(trip.stepCount), label: "Steps")
                        statCard(value: "\(detectedStops.count > 0 ? detectedStops.count : trip.placeCounts.values.reduce(0, +))", label: "Stops")
                        topCategoryCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
                .padding(.top, 14)

                // MARK: Category Chips
                if !trip.placeCounts.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(trip.placeCounts.sorted(by: { $0.value > $1.value }), id: \.key) { key, count in
                            categoryChip(key: key, count: count)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // MARK: Points of Interest Timeline
                if !detectedStops.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionTitle("Points of interest", trailing: "\(detectedStops.count)")
                            .padding(.bottom, 10)

                        ZStack(alignment: .leading) {
                            // Vertical connecting line
                            Rectangle()
                                .fill(Color.Nomad.surfaceBorder.opacity(0.15))
                                .frame(width: 1)
                                .padding(.leading, 13)
                                .padding(.top, 8)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                ForEach(detectedStops) { stop in
                                    poiRow(stop: stop)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                } else if !isLoadingRoute && trip.placeCounts.values.reduce(0, +) == 0 {
                    Text("No stops on this trip.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.Nomad.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 20)
                }

                // MARK: Photo Grid (3-column)
                if ownerUID == nil {
                    photoGridSection()
                        .padding(.top, 20)
                }

                // MARK: Share CTA
                if ownerUID == nil {
                    Button { showShareSheet = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Share Trip")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Color.Nomad.panelBlack)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.Nomad.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                }

                Spacer(minLength: 32)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .panelGradient()
        .presentationBackground(Color.Nomad.panelBlack)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showShareSheet) {
            TripShareSheet(trip: trip)
        }
        .task {
            await fetchRoutePoints()
        }
        .task {
            if ownerUID == nil {
                await loadPhotoGrid()
            }
        }
    }

    // MARK: - Section Title

    private func sectionTitle(_ title: String, trailing: String? = nil) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.Nomad.textSecondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Nomad.textSecondary)
            }
        }
    }

    // MARK: - Stat Card

    private func statCard(value: String, label: String, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.custom("CalSans-Regular", size: 22))
                    .foregroundStyle(Color.Nomad.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let unit {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.Nomad.textSecondary)
                }
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.Nomad.textSecondary)
                .tracking(0.3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.Nomad.globeBackground.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.Nomad.surfaceBorder.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func topCategoryCard() -> some View {
        let (symbol, name) = topCategoryInfo()
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.Nomad.accent)
            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(Color.Nomad.textSecondary)
                .tracking(0.3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.Nomad.globeBackground.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.Nomad.surfaceBorder.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Category Chip

    private func categoryChip(key: String, count: Int) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(categoryColor(for: key))
                .frame(width: 6, height: 6)
            Text(key.capitalized)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.Nomad.textPrimary)
            Text("· \(count)")
                .font(.system(size: 11))
                .foregroundStyle(Color.Nomad.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.Nomad.globeBackground.opacity(0.5))
        .overlay(Capsule().stroke(Color.Nomad.surfaceBorder.opacity(0.12), lineWidth: 1))
        .clipShape(Capsule())
    }

    private func categoryColor(for key: String) -> Color {
        switch key.lowercased() {
        case "food":      return Color(hue: 0.072, saturation: 0.55, brightness: 0.60)  // hue 26
        case "culture":   return Color(hue: 0.778, saturation: 0.55, brightness: 0.60)  // hue 280
        case "nature":    return Color(hue: 0.361, saturation: 0.55, brightness: 0.60)  // hue 130
        case "nightlife": return Color(hue: 0.556, saturation: 0.55, brightness: 0.60)  // hue 200
        case "wellness":  return Color(hue: 0.944, saturation: 0.55, brightness: 0.60)  // hue 340
        case "local":     return Color(hue: 0.500, saturation: 0.55, brightness: 0.60)  // hue 180
        default:          return Color.Nomad.accent
        }
    }

    // MARK: - POI Row

    private func poiRow(stop: DetectedStop) -> some View {
        let isExpanded = expandedStopId == stop.id

        return Button {
            withAnimation(.easeInOut(duration: 0.28)) {
                expandedStopId = expandedStopId == stop.id ? nil : stop.id
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Numbered pin circle
                ZStack {
                    Circle()
                        .fill(isExpanded ? Color.white : Color.Nomad.accent)
                        .frame(width: 28, height: 28)
                        .shadow(color: isExpanded ? Color.Nomad.accent.opacity(0.3) : .clear, radius: isExpanded ? 6 : 0)

                    Text("\(stop.id)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.Nomad.panelBlack)
                }

                VStack(alignment: .leading, spacing: 3) {
                    // Name + time
                    HStack(alignment: .firstTextBaseline) {
                        Text(stop.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.Nomad.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(formatTime(stop.arrivalTime))
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.Nomad.textSecondary)
                    }

                    // Duration tag
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.Nomad.accent)
                        Text("Stayed \(stop.dwellMinutes) min")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.Nomad.textSecondary)
                    }

                    // Expandable detail
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(stop.coordinate.latitude, specifier: "%.4f"), \(stop.coordinate.longitude, specifier: "%.4f")")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.Nomad.textSecondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.Nomad.globeBackground.opacity(0.6))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.Nomad.surfaceBorder.opacity(0.1), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 5)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo Grid Section

    @ViewBuilder
    private func photoGridSection() -> some View {
        if photoPermissionDenied {
            VStack(spacing: 8) {
                Text("Allow photo access in Settings to see trip photos.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Nomad.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.Nomad.accent)
            }
            .padding(.horizontal, 16)
        } else if isLoadingPhotos {
            ProgressView()
                .frame(height: 80)
                .frame(maxWidth: .infinity)
        } else if photoThumbnails.isEmpty {
            Text("No photos for this trip.")
                .font(.system(size: 13))
                .foregroundStyle(Color.Nomad.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Moments", trailing: "\(totalPhotoCount)")
                    .padding(.horizontal, 20)

                // 3-column grid
                let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(photoThumbnails.prefix(6), id: \.id) { item in
                        Image(uiImage: item.image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minHeight: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Pause Detection

    private struct PauseCluster {
        let startIndex: Int
        let endIndex: Int       // exclusive
        let centroid: CLLocationCoordinate2D
        let arrivalTime: Date
        let dwellSeconds: TimeInterval
    }

    private func detectPauseClusters(
        from points: [TimestampedCoordinate],
        radiusMeters: Double = 40,
        minDuration: TimeInterval = 90
    ) -> [PauseCluster] {
        guard points.count > 1 else { return [] }

        var clusters: [PauseCluster] = []
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
                let duration = points[i - 1].timestamp.timeIntervalSince(points[clusterStart].timestamp)
                if duration >= minDuration {
                    let slice = Array(points[clusterStart..<i])
                    clusters.append(PauseCluster(
                        startIndex: clusterStart,
                        endIndex: i,
                        centroid: centroid(of: slice),
                        arrivalTime: points[clusterStart].timestamp,
                        dwellSeconds: duration
                    ))
                }
                clusterStart = i
            }
        }

        // Final cluster
        if let last = points.last {
            let duration = last.timestamp.timeIntervalSince(points[clusterStart].timestamp)
            if duration >= minDuration {
                let slice = Array(points[clusterStart...])
                clusters.append(PauseCluster(
                    startIndex: clusterStart,
                    endIndex: points.count,
                    centroid: centroid(of: slice),
                    arrivalTime: points[clusterStart].timestamp,
                    dwellSeconds: duration
                ))
            }
        }

        return clusters
    }

    private func centroid(of points: [TimestampedCoordinate]) -> CLLocationCoordinate2D {
        let lat = points.map(\.coordinate.latitude).reduce(0, +) / Double(points.count)
        let lon = points.map(\.coordinate.longitude).reduce(0, +) / Double(points.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Geocoding Stops

    private func geocodeStops(_ clusters: [PauseCluster]) async -> [DetectedStop] {
        var stops: [DetectedStop] = []
        let geocoder = CLGeocoder()

        for (i, cluster) in clusters.enumerated() {
            var name = "Stop \(i + 1)"
            let location = CLLocation(
                latitude: cluster.centroid.latitude,
                longitude: cluster.centroid.longitude
            )

            // Sequential geocoding — CLGeocoder allows one at a time
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location) {
                name = placemarks.first?.name
                    ?? placemarks.first?.locality
                    ?? name
            }

            stops.append(DetectedStop(
                id: i + 1,
                coordinate: cluster.centroid,
                arrivalTime: cluster.arrivalTime,
                dwellMinutes: max(1, Int(cluster.dwellSeconds / 60)),
                name: name
            ))
        }

        return stops
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

    // MARK: - Route Fetch

    private func fetchRoutePoints() async {
        guard let uid = ownerUID ?? Auth.auth().currentUser?.uid else {
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

            // Detect stops and geocode them
            let clusters = detectPauseClusters(from: timed)
            detectedStops = await geocodeStops(clusters)
        } catch {
            print("[TripDetail] Route fetch error: \(error)")
            routeFetchError = true
        }
        isLoadingRoute = false
    }

    // MARK: - Photo Loading

    private func loadPhotoGrid() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard newStatus == .authorized || newStatus == .limited else {
                await MainActor.run { photoPermissionDenied = true; isLoadingPhotos = false }
                return
            }
        } else {
            guard status == .authorized || status == .limited else {
                await MainActor.run { photoPermissionDenied = true; isLoadingPhotos = false }
                return
            }
        }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            trip.startDate as CVarArg, trip.endDate as CVarArg
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let allAssets = PHAsset.fetchAssets(with: .image, options: options)

        var matchedAssets: [PHAsset] = []
        let bbox = boundingBox
        allAssets.enumerateObjects { asset, _, _ in
            if let loc = asset.location, let bbox {
                let lat = loc.coordinate.latitude
                let lon = loc.coordinate.longitude
                if lat >= bbox.minLat && lat <= bbox.maxLat &&
                   lon >= bbox.minLon && lon <= bbox.maxLon {
                    matchedAssets.append(asset)
                }
            } else {
                matchedAssets.append(asset)
            }
        }

        let total = matchedAssets.count
        let targetSize = CGSize(width: 240, height: 240) // Higher res for grid tiles
        let imageOptions = PHImageRequestOptions()
        imageOptions.deliveryMode = .fastFormat
        imageOptions.isSynchronous = false
        imageOptions.isNetworkAccessAllowed = true

        var loaded: [(id: String, image: UIImage)] = []
        let manager = PHImageManager.default()

        for asset in matchedAssets.prefix(6) {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                var resumed = false
                manager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: imageOptions
                ) { image, info in
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if !isDegraded && !resumed {
                        resumed = true
                        if let img = image {
                            loaded.append((id: asset.localIdentifier, image: img))
                        }
                        cont.resume()
                    }
                }
            }
        }

        await MainActor.run {
            photoThumbnails = loaded
            totalPhotoCount = total
            isLoadingPhotos = false
        }
    }

    // MARK: - Helpers

    private func computeBoundingBox(from coords: [CLLocationCoordinate2D])
        -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        guard !coords.isEmpty else { return nil }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
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

        if calendar.isDate(trip.startDate, inSameDayAs: trip.endDate) {
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: trip.startDate)
        } else if startComponents.month == endComponents.month &&
           startComponents.year == endComponents.year {
            formatter.dateFormat = "MMMM d"
            let start = formatter.string(from: trip.startDate)
            formatter.dateFormat = "d, yyyy"
            let end = formatter.string(from: trip.endDate)
            return "\(start) \u{2013} \(end)"
        } else {
            formatter.dateFormat = "MMM d"
            let start = formatter.string(from: trip.startDate)
            formatter.dateFormat = "MMM d, yyyy"
            let end = formatter.string(from: trip.endDate)
            return "\(start) \u{2013} \(end)"
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
            return "\(hours)h \(String(format: "%02d", minutes))m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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

// MARK: - FlowLayout
//
// Wrapping horizontal layout for category chips — matches the design's flexWrap behavior.

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews)
        -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
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
