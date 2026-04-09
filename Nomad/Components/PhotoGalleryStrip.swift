import SwiftUI
import Photos

// MARK: - PhotoGalleryStrip
//
// Horizontal scroll strip of PHAsset thumbnails matched by trip date range and GPS bounding box.
// DETAIL-03: Thumbnails loaded from Photos library matching date + GPS bounding box.
// DETAIL-04: Photos with nil location included via date-range-only fallback.
// T-03-10: Authorization checked before any fetch; photos never uploaded to server.
// D-18: Tap on thumbnails disabled in this phase — no gesture recognizer.

struct PhotoGalleryStrip: View {
    let startDate: Date
    let endDate: Date
    let boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)?

    @State private var thumbnails: [(id: String, image: UIImage)] = []
    @State private var isLoading = true
    @State private var permissionDenied = false

    var body: some View {
        Group {
            if permissionDenied {
                // Permission denied state per UI-SPEC Copywriting
                VStack(spacing: 8) {
                    Text("Allow photo access in Settings to see trip photos.")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(AppFont.caption())
                    .foregroundStyle(Color.Nomad.accent)
                }
                .padding(.horizontal, 16)
            } else if isLoading {
                ProgressView()
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
            } else if thumbnails.isEmpty {
                // Empty state per UI-SPEC Copywriting
                Text("No photos for this trip.")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.Nomad.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(thumbnails, id: \.id) { item in
                            Image(uiImage: item.image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            // D-18: Tap disabled in this phase — no gesture recognizer
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 80)
            }
        }
        .task {
            await loadPhotos()
        }
    }

    // MARK: - Photo Loading (T-03-10: check authorization before fetching)

    private func loadPhotos() async {
        // Check authorization — T-03-10
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard newStatus == .authorized || newStatus == .limited else {
                await MainActor.run { permissionDenied = true; isLoading = false }
                return
            }
        } else {
            guard status == .authorized || status == .limited else {
                await MainActor.run { permissionDenied = true; isLoading = false }
                return
            }
        }

        // Fetch PHAssets within trip date range
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            startDate as CVarArg, endDate as CVarArg
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let allAssets = PHAsset.fetchAssets(with: .image, options: options)

        var matchedAssets: [PHAsset] = []
        allAssets.enumerateObjects { asset, _, _ in
            if let loc = asset.location, let bbox = boundingBox {
                // Pass 1: GPS bounding box filter
                let lat = loc.coordinate.latitude
                let lon = loc.coordinate.longitude
                if lat >= bbox.minLat && lat <= bbox.maxLat &&
                   lon >= bbox.minLon && lon <= bbox.maxLon {
                    matchedAssets.append(asset)
                }
            } else {
                // DETAIL-04: nil location — include via date-range-only fallback
                matchedAssets.append(asset)
            }
        }

        // Load thumbnails on background thread via PHImageManager
        let targetSize = CGSize(width: 160, height: 160) // 2x for retina
        let imageOptions = PHImageRequestOptions()
        imageOptions.deliveryMode = .fastFormat
        imageOptions.isSynchronous = false
        imageOptions.isNetworkAccessAllowed = true

        var loaded: [(id: String, image: UIImage)] = []
        let manager = PHImageManager.default()

        // Cap at 50 thumbnails for performance
        for asset in matchedAssets.prefix(50) {
            // Use resumed-flag pattern: PHImageManager may deliver degraded frame first,
            // then the final image. We only resume once the non-degraded frame arrives.
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
            thumbnails = loaded
            isLoading = false
        }
    }
}
