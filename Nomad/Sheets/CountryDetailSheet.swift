import SwiftUI
import Photos
import CoreLocation
@preconcurrency import MapKit

// MARK: - CountryDetailViewModel
//
// Loads city clusters, representative photos, and temperatures per cluster
// for the CountryDetailSheet.
// T-3.1-03: PHPhotoLibrary.authorizationStatus checked before any photo fetch.
// T-3.1-04: Trip data is pre-filtered by caller — no additional auth check needed.

@Observable
@MainActor
final class CountryDetailViewModel {
    let countryCode: String
    let countryName: String
    let allCountryTrips: [TripDocument]

    var clusters: [CityCluster] = []
    var selectedCityIndex: Int = 0
    var isLoading = true

    // Per-cluster state (keyed by CityCluster.id)
    var cityPhotos: [UUID: [UIImage]] = [:]
    var temperatures: [UUID: String?] = [:]  // nil inner value = hide pill, absent key = still loading
    var photoCountPerCluster: [UUID: Int] = [:]

    var selectedCluster: CityCluster? {
        clusters[safe: selectedCityIndex]
    }

    init(countryCode: String, countryName: String, trips: [TripDocument]) {
        self.countryCode = countryCode
        self.countryName = countryName
        self.allCountryTrips = trips
    }

    func load() async {
        clusters = clusterTripsByProximity(allCountryTrips)
        isLoading = false

        await withTaskGroup(of: Void.self) { group in
            for cluster in clusters {
                group.addTask { [weak self] in
                    await self?.loadCluster(cluster)
                }
            }
        }
    }

    // MARK: - Bounding Box Helper

    private func boundingBox(for cluster: CityCluster) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        let coords = cluster.trips.flatMap { $0.routePreview }
        guard !coords.isEmpty else { return nil }
        let lats = coords.compactMap { $0.first }   // $0[0] = lat
        let lons = coords.compactMap { $0.last }     // $0[1] = lon
        guard !lats.isEmpty, !lons.isEmpty else { return nil }
        return (lats.min()!, lats.max()!, lons.min()!, lons.max()!)
    }

    // MARK: - Memory Eviction

    func evictDistantPhotos() {
        let visibleRange = max(0, selectedCityIndex - 2)...min(clusters.count - 1, selectedCityIndex + 2)
        for (index, cluster) in clusters.enumerated() {
            if !visibleRange.contains(index) {
                cityPhotos[cluster.id] = nil
            }
        }
    }

    private func loadCluster(_ cluster: CityCluster) async {
        // Reverse geocode centroid to get real city/locality name
        let centroidLocation = CLLocation(
            latitude: cluster.centroid.latitude,
            longitude: cluster.centroid.longitude
        )
        if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(centroidLocation),
           let placemark = placemarks.first,
           let idx = clusters.firstIndex(where: { $0.id == cluster.id }) {
            let locality = placemark.locality ?? placemark.subLocality ?? placemark.administrativeArea
            if let locality {
                clusters[idx].cityName = locality
            }
        }

        // T-3.1-03: Check photo authorization before fetching
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authStatus == .authorized || authStatus == .limited {
            let dateRange = cluster.dateRange

            // Fetch all photos for cluster date range + GPS bounding box
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                dateRange.start as CVarArg,
                dateRange.end as CVarArg
            )
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            // No fetchLimit — load all photos for the city

            let result = PHAsset.fetchAssets(with: .image, options: options)
            let bbox = boundingBox(for: cluster)
            var matchedAssets: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in
                if let loc = asset.location, let bbox = bbox {
                    let lat = loc.coordinate.latitude
                    let lon = loc.coordinate.longitude
                    if lat >= bbox.minLat && lat <= bbox.maxLat &&
                       lon >= bbox.minLon && lon <= bbox.maxLon {
                        matchedAssets.append(asset)
                    }
                } else {
                    // nil location — date-range-only fallback (DETAIL-04 pattern)
                    matchedAssets.append(asset)
                }
            }

            // Load images with opportunistic delivery
            let screenWidth = await UIScreen.main.bounds.width
            let targetSize = CGSize(width: screenWidth * 3, height: 960)
            var loadedImages: [UIImage] = []
            for asset in matchedAssets {
                let image: UIImage? = await withCheckedContinuation { cont in
                    var resumed = false
                    let reqOptions = PHImageRequestOptions()
                    reqOptions.deliveryMode = .opportunistic
                    reqOptions.isSynchronous = false
                    reqOptions.isNetworkAccessAllowed = true

                    PHImageManager.default().requestImage(
                        for: asset,
                        targetSize: targetSize,
                        contentMode: .aspectFill,
                        options: reqOptions
                    ) { image, info in
                        let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                        if !isDegraded && !resumed {
                            resumed = true
                            cont.resume(returning: image)
                        }
                    }
                }
                if let image { loadedImages.append(image) }
            }
            cityPhotos[cluster.id] = loadedImages
            photoCountPerCluster[cluster.id] = loadedImages.count
        }

        // Fetch temperature regardless of photo auth
        let temp = await NomadWeatherService.shared.fetchTemperature(for: cluster.centroid)
        temperatures[cluster.id] = temp
    }
}

// MARK: - Safe subscript extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

// MARK: - CountryDetailSheet

struct CountryDetailSheet: View {
    let countryCode: String
    let countryName: String
    let trips: [TripDocument]
    let initialCityName: String?

    @State private var viewModel: CountryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showTripDetail = false
    @State private var selectedTripForDetail: TripDocument? = nil

    init(countryCode: String, trips: [TripDocument], initialCityName: String? = nil) {
        self.countryCode = countryCode
        self.countryName = Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
        self.trips = trips
        self.initialCityName = initialCityName
        let name = Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
        self._viewModel = State(initialValue: CountryDetailViewModel(
            countryCode: countryCode,
            countryName: name,
            trips: trips
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Country Header Row — PERSISTENT, outside TabView (D-04)
            countryHeaderRow
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // Loading state
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.clusters.isEmpty {
                // Empty state — no cities
                cityStripSection
                Spacer()
            } else {
                // 2. Outer city TabView — full page swipe between cities (D-08)
                TabView(selection: $viewModel.selectedCityIndex) {
                    ForEach(Array(viewModel.clusters.enumerated()), id: \.element.id) { index, cluster in
                        cityDetailPage(for: cluster, at: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                .onChange(of: viewModel.selectedCityIndex) { _, _ in
                    viewModel.evictDistantPhotos()
                }
            }
        }
        .panelGradient()
        .presentationBackground(Color.Nomad.panelBlack)
        .presentationDetents([.fraction(0.25), .medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await viewModel.load()
            if let cityName = initialCityName,
               let idx = viewModel.clusters.firstIndex(where: {
                   $0.cityName.localizedCaseInsensitiveContains(cityName)
               }) {
                viewModel.selectedCityIndex = idx
            }
        }
        .sheet(isPresented: $showTripDetail) {
            if let trip = selectedTripForDetail {
                TripDetailSheet(trip: trip)
            }
        }
    }

    // MARK: - Country Header Row

    private var countryHeaderRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.Nomad.textPrimary)
                    .frame(width: 44, height: 44)
            }

            Text(countryName)
                .font(AppFont.title())
                .foregroundStyle(Color.Nomad.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - City Detail Page

    @ViewBuilder
    private func cityDetailPage(for cluster: CityCluster, at index: Int) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // City strip — repeated per page with correct selection state (D-07)
                cityStripSection

                // Multi-photo carousel (D-02) — uses CityPhotoCarousel from Plan 01
                CityPhotoCarousel(
                    cluster: cluster,
                    photos: viewModel.cityPhotos[cluster.id] ?? [],
                    temperature: viewModel.temperatures[cluster.id].flatMap { $0 },
                    countryName: viewModel.countryName
                )
                .padding(.top, 16)

                // Stats pill — city-scoped (D-10)
                StatsPillRow(
                    tripCount: cluster.tripCount,
                    distanceKm: cluster.totalDistanceKm,
                    photoCount: viewModel.photoCountPerCluster[cluster.id] ?? 0
                )
                .padding(.top, 16)

                // Trip logs — city-scoped (D-11)
                tripLogsSection(for: cluster)
                    .padding(.top, 24)
                    .padding(.horizontal, 16)

                Spacer(minLength: 64) // bottom scroll clearance
            }
        }
    }

    // MARK: - City Strip Section

    @ViewBuilder
    private var cityStripSection: some View {
        if viewModel.clusters.isEmpty && !viewModel.isLoading {
            VStack(alignment: .leading, spacing: 8) {
                Text("No visits yet.")
                    .font(AppFont.subheading())
                    .foregroundStyle(Color.Nomad.textPrimary)
                Text("Log a trip in \(countryName) to see your cities here.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.Nomad.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.clusters.enumerated()), id: \.element.id) { index, cluster in
                        CityThumbnailCard(
                            cityName: cluster.cityName,
                            photo: viewModel.cityPhotos[cluster.id]?.first,
                            isSelected: index == viewModel.selectedCityIndex
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                viewModel.selectedCityIndex = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 100)
        }
    }

    // MARK: - Trip Logs Section

    @ViewBuilder
    private func tripLogsSection(for cluster: CityCluster) -> some View {
        let trips = cluster.trips.sorted { $0.startDate < $1.startDate }

        if trips.isEmpty {
            Text("No trips logged for \(cluster.cityName).")
                .font(AppFont.caption())
                .foregroundStyle(Color.Nomad.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
        } else {
            VStack(spacing: 8) {
                ForEach(trips) { trip in
                    TripLogCard(trip: trip) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            openTripDetail(trip)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper

    func openTripDetail(_ trip: TripDocument) {
        selectedTripForDetail = trip
        showTripDetail = true
    }
}

#if DEBUG
#Preview {
    let sampleTrips = [
        TripDocument(
            id: "trip-1",
            cityName: "Vienna",
            startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .day, value: -8, to: Date()) ?? Date(),
            stepCount: 18000,
            distanceMeters: 12000,
            routePreview: [[48.2082, 16.3738]],
            visitedCountryCodes: ["AT"],
            placeCounts: ["culture": 3, "food": 2]
        ),
        TripDocument(
            id: "trip-2",
            cityName: "Salzburg",
            startDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            stepCount: 9000,
            distanceMeters: 6000,
            routePreview: [[47.8095, 13.0550]],
            visitedCountryCodes: ["AT"],
            placeCounts: ["culture": 2, "nature": 1]
        )
    ]
    CountryDetailSheet(countryCode: "AT", trips: sampleTrips)
}
#endif
