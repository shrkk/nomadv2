import SwiftUI
import Photos

// MARK: - CityPhotoCarousel
//
// Full-width paged TabView carousel showing one photo per city cluster.
// T-3.1-05: PHPhotoLibrary authorization checked — denied/restricted state shown in carousel.
// Synced bidirectionally with selectedCityIndex binding.
//
// Also contains the Location Identity Block below the photo area.

struct CityPhotoCarousel: View {
    let clusters: [CityCluster]
    @Binding var selectedCityIndex: Int
    let photos: [UUID: UIImage]
    let temperatures: [UUID: String?]
    let countryName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full-width paged TabView
            TabView(selection: $selectedCityIndex) {
                ForEach(Array(clusters.enumerated()), id: \.element.id) { index, cluster in
                    ZStack(alignment: .top) {
                        photoArea(for: cluster)
                        temperatureOverlay(for: cluster)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 320)

            // Location Identity Block
            locationIdentityBlock
        }
    }

    // MARK: - Photo Area

    @ViewBuilder
    private func photoArea(for cluster: CityCluster) -> some View {
        // T-3.1-05: Check photo authorization
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authStatus == .denied || authStatus == .restricted {
            // Permission denied state
            ZStack {
                Color.Nomad.warmCard
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                VStack(spacing: 8) {
                    Text("Allow photo access in Settings.")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.globeBackground.opacity(0.6))
                        .multilineTextAlignment(.center)
                    Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.amber)
                }
                .padding(.horizontal, 16)
            }
        } else if let uiImage = photos[cluster.id] {
            // Photo loaded
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .clipped()
        } else {
            // Empty / loading placeholder
            ZStack {
                Color.Nomad.warmCard
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                Text("No photos for \(cluster.cityName).")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.Nomad.globeBackground.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Temperature Overlay

    @ViewBuilder
    private func temperatureOverlay(for cluster: CityCluster) -> some View {
        // Only show pill when temperature is non-nil (nil inner value = hide pill)
        if let tempOptional = temperatures[cluster.id], let temp = tempOptional {
            TemperatureNotchPill(temperature: temp)
                .offset(y: -14)
        }
        // else: pill hidden per UI-SPEC Unavailable state
    }

    // MARK: - Location Identity Block

    private var locationIdentityBlock: some View {
        let selectedCluster = clusters[safe: selectedCityIndex]
        let cityName = selectedCluster?.cityName ?? ""

        return VStack(alignment: .leading, spacing: 4) {
            Text(cityName)
                .font(AppFont.subheading())
                .foregroundStyle(Color.Nomad.globeBackground)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(countryName), \(cityName)")
                .font(AppFont.body())
                .foregroundStyle(Color.Nomad.globeBackground.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#if DEBUG
#Preview {
    let clusters: [CityCluster] = []
    CityPhotoCarousel(
        clusters: clusters,
        selectedCityIndex: .constant(0),
        photos: [:],
        temperatures: [:],
        countryName: "Austria"
    )
    .background(Color.Nomad.cream)
}
#endif
