import SwiftUI
import UIKit
import Photos
import CoreLocation

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
    var photos: [UUID: UIImage] = [:]
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

    private func loadCluster(_ cluster: CityCluster) async {
        // T-3.1-03: Check photo authorization before fetching
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authStatus == .authorized || authStatus == .limited {
            let dateRange = cluster.dateRange

            // Fetch representative photo (first by date, limited to 1)
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                dateRange.start as CVarArg,
                dateRange.end as CVarArg
            )
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            options.fetchLimit = 1

            let result = PHAsset.fetchAssets(with: .image, options: options)
            if let asset = result.firstObject {
                let screenWidth = await UIScreen.main.bounds.width
                let targetSize = CGSize(width: screenWidth * 3, height: 960)
                let image: UIImage? = await withCheckedContinuation { cont in
                    var resumed = false
                    let reqOptions = PHImageRequestOptions()
                    reqOptions.deliveryMode = .highQualityFormat
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
                if let image = image {
                    photos[cluster.id] = image
                }
            }

            // Count total photos for stats pill
            let countOptions = PHFetchOptions()
            countOptions.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                dateRange.start as CVarArg,
                dateRange.end as CVarArg
            )
            let allAssets = PHAsset.fetchAssets(with: .image, options: countOptions)
            photoCountPerCluster[cluster.id] = allAssets.count
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

    @State private var viewModel: CountryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showTripDetail = false
    @State private var selectedTripForDetail: TripDocument? = nil

    init(countryCode: String, trips: [TripDocument]) {
        self.countryCode = countryCode
        self.countryName = Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
        self.trips = trips
        let name = Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
        self._viewModel = State(initialValue: CountryDetailViewModel(
            countryCode: countryCode,
            countryName: name,
            trips: trips
        ))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Country Header Row
                countryHeaderRow
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                // City Strip
                cityStripSection

                // Photo Carousel — Plan 03 will add here
                // Location Identity — Plan 03 will add here
                // Stats Pill — Plan 03 will add here
                // Trip Logs — Plan 03 will add here

                // Placeholder for Plan 03 content
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                }

                Spacer(minLength: 64) // bottom scroll clearance
            }
        }
        .panelGradient()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await viewModel.load() }
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
                    .foregroundStyle(Color.Nomad.amber)
                    .frame(width: 44, height: 44)
            }

            Text(countryName)
                .font(AppFont.title())
                .foregroundStyle(Color.Nomad.globeBackground)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - City Strip Section

    @ViewBuilder
    private var cityStripSection: some View {
        if viewModel.clusters.isEmpty && !viewModel.isLoading {
            // Empty state — per UI-SPEC Copywriting
            VStack(alignment: .leading, spacing: 8) {
                Text("No visits yet.")
                    .font(AppFont.subheading())
                    .foregroundStyle(Color.Nomad.globeBackground)
                Text("Log a trip in \(countryName) to see your cities here.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.Nomad.globeBackground.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.clusters.enumerated()), id: \.element.id) { index, cluster in
                        CityThumbnailCard(
                            cityName: cluster.cityName,
                            photo: viewModel.photos[cluster.id],
                            isSelected: index == viewModel.selectedCityIndex
                        )
                        .onTapGesture {
                            viewModel.selectedCityIndex = index
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 100)
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
