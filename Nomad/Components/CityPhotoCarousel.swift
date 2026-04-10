import SwiftUI
import Photos

// MARK: - CityPhotoCarousel
//
// Multi-photo paged carousel for a single city cluster.
// D-02: Shows ALL photos for the selected city — swipeable full-width paged carousel.
// D-05: Photos are view-only — no tap interaction, no full-screen viewer, no zoom.
// Inner TabView pages between photos within one city.
// Page indicator dots shown only when 2+ photos (per UI-SPEC).

struct CityPhotoCarousel: View {
    let cluster: CityCluster
    let photos: [UIImage]
    let temperature: String?
    let countryName: String

    @State private var photoIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                // Inner photo TabView — pages between photos within this city
                TabView(selection: $photoIndex) {
                    if photos.isEmpty {
                        emptyPhotoPlaceholder
                            .tag(0)
                    } else {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 320)
                                .clipped()
                                .contentShape(Rectangle()) // D-05: no tap action
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottom) {
                    // Photo page indicator dots — only if 2+ photos (UI-SPEC)
                    if photos.count >= 2 {
                        photoPageIndicator
                            .padding(.bottom, 8)
                    }
                }

                // Temperature notch overlay — per cluster, not per photo
                if let temp = temperature {
                    TemperatureNotchPill(temperature: temp)
                        .padding(.top, 12)
                }
            }

            // Location Identity Block
            locationIdentityBlock
        }
    }

    // MARK: - Empty Photo Placeholder

    @ViewBuilder
    private var emptyPhotoPlaceholder: some View {
        // T-3.1-05: Check photo authorization
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authStatus == .denied || authStatus == .restricted {
            ZStack {
                Color.Nomad.panelBlack
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                VStack(spacing: 8) {
                    Text("Allow photo access in Settings.")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.textSecondary)
                        .multilineTextAlignment(.center)
                    Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.accent)
                }
                .padding(.horizontal, 16)
            }
        } else {
            ZStack {
                Color.Nomad.panelBlack
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                Text("No photos for \(cluster.cityName).")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.Nomad.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Photo Page Indicator Dots

    private var photoPageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<photos.count, id: \.self) { i in
                Circle()
                    .fill(i == photoIndex ? Color.Nomad.accent : Color.Nomad.textSecondary.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Location Identity Block

    private var locationIdentityBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(cluster.cityName)
                .font(AppFont.subheading())
                .foregroundStyle(Color.Nomad.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(countryName), \(cluster.cityName)")
                .font(AppFont.body())
                .foregroundStyle(Color.Nomad.textSecondary)
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
    CityPhotoCarousel(
        cluster: CityCluster(
            cityName: "Vienna",
            centroid: .init(latitude: 48.2082, longitude: 16.3738),
            trips: []
        ),
        photos: [],
        temperature: "22°C",
        countryName: "Austria"
    )
    .background(Color.Nomad.panelBlack)
}
#endif
