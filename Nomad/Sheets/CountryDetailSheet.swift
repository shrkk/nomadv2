import SwiftUI
import Photos
import CoreLocation
@preconcurrency import MapKit

// MARK: - CountryDetailViewModel

@Observable
@MainActor
final class CountryDetailViewModel {
    let countryCode: String
    let countryName: String
    let allCountryTrips: [TripDocument]

    var clusters: [CityCluster] = []
    var selectedCityIndex: Int = 0
    var isLoading = true

    var cityPhotos: [UUID: [UIImage]] = [:]
    var temperatures: [UUID: String?] = [:]
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

    func removeTrip(_ trip: TripDocument) {
        for i in clusters.indices {
            clusters[i].trips.removeAll { $0.id == trip.id }
        }
        clusters.removeAll { $0.trips.isEmpty }
        if selectedCityIndex >= clusters.count {
            selectedCityIndex = max(0, clusters.count - 1)
        }
    }

    func evictDistantPhotos() {
        let visibleRange = max(0, selectedCityIndex - 2)...min(clusters.count - 1, selectedCityIndex + 2)
        for (index, cluster) in clusters.enumerated() {
            if !visibleRange.contains(index) {
                cityPhotos[cluster.id] = nil
            }
        }
    }

    private func boundingBox(for cluster: CityCluster) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        let coords = cluster.trips.flatMap { $0.routePreview }
        guard !coords.isEmpty else { return nil }
        let lats = coords.compactMap { $0.first }
        let lons = coords.compactMap { $0.last }
        guard !lats.isEmpty, !lons.isEmpty else { return nil }
        return (lats.min()!, lats.max()!, lons.min()!, lons.max()!)
    }

    private func loadCluster(_ cluster: CityCluster) async {
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

        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authStatus == .authorized || authStatus == .limited {
            let dateRange = cluster.dateRange
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                dateRange.start as CVarArg,
                dateRange.end as CVarArg
            )
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

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
                    matchedAssets.append(asset)
                }
            }

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

        let temp = await NomadWeatherService.shared.fetchTemperature(for: cluster.centroid)
        temperatures[cluster.id] = temp
    }
}

// MARK: - Safe subscript

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
    var onDeleteTrip: ((TripDocument) -> Void)? = nil

    @State private var viewModel: CountryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showTripDetail = false
    @State private var selectedTripForDetail: TripDocument? = nil
    @State private var tripToDelete: TripDocument? = nil
    @State private var showDeleteConfirmation = false

    init(countryCode: String, trips: [TripDocument], initialCityName: String? = nil, onDeleteTrip: ((TripDocument) -> Void)? = nil) {
        self.countryCode = countryCode
        self.countryName = Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
        self.trips = trips
        self.initialCityName = initialCityName
        self.onDeleteTrip = onDeleteTrip
        let name = Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
        self._viewModel = State(initialValue: CountryDetailViewModel(
            countryCode: countryCode,
            countryName: name,
            trips: trips
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Country header — persistent above everything
            countryHeaderRow
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.clusters.isEmpty {
                emptyState
                Spacer()
            } else {
                // V3: pill tab strip sits outside the TabView so it stays
                // visible and synced while the user swipes between city pages.
                cityTabStrip

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
        .alert("Delete Trip", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let trip = tripToDelete {
                    viewModel.removeTrip(trip)
                    onDeleteTrip?(trip)
                }
                tripToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                tripToDelete = nil
            }
        } message: {
            if let trip = tripToDelete {
                Text("Delete the log for \(trip.cityName)? This cannot be undone.")
            }
        }
    }

    // MARK: - Country Header

    private var countryHeaderRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Button { dismiss() } label: {
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

    // MARK: - V3 City Tab Strip

    private var cityTabStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(viewModel.clusters.enumerated()), id: \.element.id) { index, cluster in
                        cityTabPill(cluster: cluster, index: index)
                            .id(index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .onChange(of: viewModel.selectedCityIndex) { _, newIndex in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    private func cityTabPill(cluster: CityCluster, index: Int) -> some View {
        let isActive = index == viewModel.selectedCityIndex
        let photo = viewModel.cityPhotos[cluster.id]?.first

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                viewModel.selectedCityIndex = index
            }
        } label: {
            HStack(spacing: 8) {
                // 22×22pt mini thumbnail or placeholder
                Group {
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.black.opacity(isActive ? 0.5 : 0), lineWidth: 1.5)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.Nomad.globeBackground)
                            .frame(width: 22, height: 22)
                    }
                }

                Text(cluster.cityName)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? Color.Nomad.panelBlack : Color.Nomad.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                Capsule()
                    .fill(isActive ? Color.Nomad.accent : Color.Nomad.globeBackground.opacity(0.5))
            )
            .overlay(
                Capsule()
                    .stroke(
                        isActive ? Color.Nomad.accent : Color.Nomad.surfaceBorder.opacity(0.12),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: viewModel.selectedCityIndex)
    }

    // MARK: - City Detail Page

    @ViewBuilder
    private func cityDetailPage(for cluster: CityCluster, at index: Int) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Photo carousel
                CityPhotoCarousel(
                    cluster: cluster,
                    photos: viewModel.cityPhotos[cluster.id] ?? [],
                    temperature: viewModel.temperatures[cluster.id].flatMap { $0 },
                    countryName: viewModel.countryName
                )
                .padding(.top, 8)

                // V3 Identity: city name + country sub
                cityIdentity(for: cluster)

                // Stats pill
                StatsPillRow(
                    tripCount: cluster.tripCount,
                    distanceKm: cluster.totalDistanceKm,
                    photoCount: viewModel.photoCountPerCluster[cluster.id] ?? 0
                )
                .padding(.top, 4)

                // Trip logs
                tripLogsSection(for: cluster)
                    .padding(.top, 24)
                    .padding(.horizontal, 16)

                Spacer(minLength: 64)
            }
        }
    }

    // MARK: - V3 Identity Section

    private func cityIdentity(for cluster: CityCluster) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(cluster.cityName)
                .font(.custom("CalSans-Regular", size: 26))
                .foregroundStyle(Color.Nomad.textPrimary)

            Text(countryName)
                .font(.system(size: 14))
                .foregroundStyle(Color.Nomad.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
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
                    TripLogCard(trip: trip, onTap: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            openTripDetail(trip)
                        }
                    }, onDelete: {
                        tripToDelete = trip
                        showDeleteConfirmation = true
                    })
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
