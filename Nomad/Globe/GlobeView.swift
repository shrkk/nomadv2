import ActivityKit
import SwiftUI
@preconcurrency import MapKit
@preconcurrency import FirebaseAuth
import HealthKit
import SwiftData
import CoreLocation
import Photos

// MARK: - CGRect aspect-fill helper

private extension CGRect {
    /// Returns a rect that aspect-fills this rect for a source image size.
    func aspectFill(for imageSize: CGSize) -> CGRect {
        let scaleX = width / imageSize.width
        let scaleY = height / imageSize.height
        let scale = max(scaleX, scaleY)
        let newW = imageSize.width * scale
        let newH = imageSize.height * scale
        return CGRect(
            x: origin.x + (width - newW) / 2,
            y: origin.y + (height - newH) / 2,
            width: newW,
            height: newH
        )
    }
}

// MARK: - GlobeMapView
//
// MKMapView with .hybridFlyover map type renders a true 3D globe with
// Apple Maps satellite imagery and location labels at max zoom-out.

@MainActor
struct GlobeMapView: UIViewRepresentable {
    let viewModel: GlobeViewModel
    let onTapCountry: (String) -> Void
    // Explicit tracked values so SwiftUI triggers updateUIView when these change
    var homeCityCoordinate: CLLocationCoordinate2D?
    var homeCityName: String?
    var tripPhotos: [String: UIImage]
    var activeRouteCoordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator

        // hybridFlyover renders as a 3D globe (not flat projection) at high altitude
        mapView.mapType = .hybridFlyover

        // Interaction
        mapView.isRotateEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = true

        // Hide UI chrome
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsUserLocation = false

        // Set camera at orbital altitude to see the full globe
        let camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: 20, longitude: 10),
            fromDistance: 40_000_000,
            pitch: 0,
            heading: 0
        )
        mapView.setCamera(camera, animated: false)

        // Tap gesture
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Only proceed once countries are loaded
        guard !viewModel.countries.isEmpty else { return }

        // Diff trip pinpoints: re-add when trip count or photos change
        let newTripCount = viewModel.trips.count
        let newPhotoCount = tripPhotos.count
        if newTripCount != context.coordinator.cachedTripCount
            || newPhotoCount != context.coordinator.cachedPhotoCount {
            let existing = mapView.annotations.filter { $0 is TripAnnotation }
            mapView.removeAnnotations(existing)
            context.coordinator.cachedTripCount = newTripCount
            context.coordinator.cachedPhotoCount = newPhotoCount
            context.coordinator.addPinpointAnnotations(
                to: mapView, trips: viewModel.trips, photos: tripPhotos
            )
        }

        // Diff home city pin (driven by tracked homeCityCoordinate property)
        let hasHome = mapView.annotations.contains { $0 is HomeAnnotation }
        if let coord = homeCityCoordinate, !hasHome {
            let home = HomeAnnotation()
            home.coordinate = coord
            home.cityName = homeCityName ?? ""
            home.title = homeCityName
            mapView.addAnnotation(home)
        } else if homeCityCoordinate == nil && hasHome {
            let existing = mapView.annotations.filter { $0 is HomeAnnotation }
            mapView.removeAnnotations(existing)
        }

        // Orient globe to home city on first load
        if let coord = homeCityCoordinate, !context.coordinator.didOrientToHome {
            context.coordinator.didOrientToHome = true
            let camera = MKMapCamera(
                lookingAtCenter: coord,
                fromDistance: 40_000_000,
                pitch: 0,
                heading: 0
            )
            mapView.setCamera(camera, animated: true)
        }

        // Diff active route overlay
        let newRouteCount = activeRouteCoordinates.count
        if newRouteCount != context.coordinator.cachedRoutePointCount {
            // Remove existing route overlays
            let existing = mapView.overlays.filter { $0 is MKPolyline }
            mapView.removeOverlays(existing)
            context.coordinator.cachedRoutePointCount = newRouteCount

            // Draw new route if we have coordinates
            if newRouteCount >= 2 {
                var coords = activeRouteCoordinates
                let polyline = MKPolyline(coordinates: &coords, count: coords.count)
                mapView.addOverlay(polyline, level: .aboveRoads)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onTapCountry: onTapCountry)
    }

    // MARK: - Trip Annotation

    class TripAnnotation: MKPointAnnotation {
        var tripID: String = ""
        var countryCode: String = ""
        var cityName: String = ""
        var photo: UIImage? = nil
    }

    class HomeAnnotation: MKPointAnnotation {
        var cityName: String = ""
    }

    @MainActor
    class Coordinator: NSObject, MKMapViewDelegate {
        let viewModel: GlobeViewModel
        let onTapCountry: (String) -> Void
        var mapView: MKMapView?
        var cachedTripCount: Int = -1
        var cachedPhotoCount: Int = -1
        var cachedRoutePointCount: Int = 0
        var didOrientToHome = false

        init(viewModel: GlobeViewModel, onTapCountry: @escaping (String) -> Void) {
            self.viewModel = viewModel
            self.onTapCountry = onTapCountry
        }

        // MARK: - Pin Setup

        func addPinpointAnnotations(to mapView: MKMapView, trips: [TripDocument], photos: [String: UIImage]) {
            for trip in trips {
                guard let coord = trip.coordinate else { continue }
                let annotation = TripAnnotation()
                annotation.coordinate = coord
                annotation.tripID = trip.id
                annotation.countryCode = trip.visitedCountryCodes.first ?? ""
                annotation.cityName = trip.cityName
                annotation.photo = photos[trip.id]
                mapView.addAnnotation(annotation)
            }
        }

        // MARK: - Pin Rendering

        /// Renders a rectangular pin with a full-width triangle pointer at the bottom.
        private func renderPinImage(photo: UIImage?, pinWidth: CGFloat, pinHeight: CGFloat) -> UIImage {
            let margin: CGFloat = 4
            let w = pinWidth                     // rectangle width
            let h = pinHeight                    // rectangle height
            let cr: CGFloat = 8
            let borderW: CGFloat = 3
            let triH: CGFloat = 10               // triangle height

            let canvasW = w + margin * 2
            let canvasH = h + triH + margin * 2

            let rectFrame = CGRect(x: margin, y: margin, width: w, height: h)
            let cx = margin + w / 2

            let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasW, height: canvasH))
            return renderer.image { _ in
                let ctx = UIGraphicsGetCurrentContext()!

                // Photo clipped to the rectangle
                let rectPath = UIBezierPath(roundedRect: rectFrame, cornerRadius: cr)
                ctx.saveGState()
                rectPath.addClip()
                if let photo {
                    photo.draw(in: rectFrame.aspectFill(for: photo.size))
                } else {
                    UIColor(hex: 0x0C2457).setFill()
                    rectPath.fill()
                }
                ctx.restoreGState()

                // Rectangle border
                UIColor(hex: 0x0F0F28).setStroke()
                let borderPath = UIBezierPath(roundedRect: rectFrame, cornerRadius: cr)
                borderPath.lineWidth = borderW
                borderPath.stroke()

                // Triangle — full width of the rectangle
                let triTop = rectFrame.maxY
                let triPath = UIBezierPath()
                triPath.move(to: CGPoint(x: margin, y: triTop))
                triPath.addLine(to: CGPoint(x: cx, y: triTop + triH))
                triPath.addLine(to: CGPoint(x: margin + w, y: triTop))
                triPath.close()

                UIColor(hex: 0x0F0F28).setFill()
                triPath.fill()

                // Camera icon fallback
                if photo == nil {
                    let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
                    if let icon = UIImage(systemName: "camera.fill")?
                        .withTintColor(UIColor(hex: 0xE1E2F0), renderingMode: .alwaysOriginal)
                        .withConfiguration(config) {
                        icon.draw(at: CGPoint(x: rectFrame.midX - icon.size.width / 2,
                                              y: rectFrame.midY - icon.size.height / 2))
                    }
                }
            }
        }

        /// Renders a cluster pin: photo pin with a count badge in the top-right.
        private func renderClusterPinImage(photo: UIImage?, count: Int,
                                           pinWidth: CGFloat, pinHeight: CGFloat) -> UIImage {
            let badgeSize: CGFloat = 22

            // Render the base pin — its size includes margin
            let basePin = renderPinImage(photo: photo, pinWidth: pinWidth, pinHeight: pinHeight)
            let baseSize = basePin.size

            let renderer = UIGraphicsImageRenderer(size: baseSize)
            return renderer.image { _ in
                basePin.draw(at: .zero)

                // Badge circle — top-right corner of the pin canvas
                let badgeX = baseSize.width - badgeSize - 2
                let badgeY: CGFloat = 0
                let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeSize, height: badgeSize)

                UIColor(hex: 0x2D62D3).setFill()
                UIBezierPath(ovalIn: badgeRect).fill()
                UIColor(hex: 0xC8D7F3).setStroke()
                let borderPath = UIBezierPath(ovalIn: badgeRect.insetBy(dx: 1, dy: 1))
                borderPath.lineWidth = 1.5
                borderPath.stroke()

                // Count text
                let text = "\(count)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: UIColor(hex: 0xE1E2F0),
                ]
                let textSize = text.size(withAttributes: attrs)
                let textOrigin = CGPoint(
                    x: badgeRect.midX - textSize.width / 2,
                    y: badgeRect.midY - textSize.height / 2
                )
                text.draw(at: textOrigin, withAttributes: attrs)
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(hex: 0x5EE0DD, alpha: 0.9)
                renderer.lineWidth = 2.0
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Home city pin with house icon on accent circle
            if let home = annotation as? HomeAnnotation {
                let id = "HomePinpoint"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id)
                            ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id))
                view.annotation = home
                view.canShowCallout = true

                let size: CGFloat = 44
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                view.image = renderer.image { ctx in
                    UIColor(hex: 0x2D62D3).setFill()
                    UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).fill()
                    UIColor(hex: 0xC8D7F3).setStroke()
                    let border = UIBezierPath(ovalIn: CGRect(x: 1.5, y: 1.5, width: size - 3, height: size - 3))
                    border.lineWidth = 3
                    border.stroke()
                    let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
                    if let icon = UIImage(systemName: "house.fill")?
                        .withTintColor(UIColor(hex: 0xE1E2F0), renderingMode: .alwaysOriginal)
                        .withConfiguration(config) {
                        let iconSize = icon.size
                        let origin = CGPoint(x: (size - iconSize.width) / 2, y: (size - iconSize.height) / 2)
                        icon.draw(at: origin)
                    }
                }
                view.frame.size = CGSize(width: size, height: size)
                return view
            }

            // Cluster annotation — multiple trips grouped together
            if let cluster = annotation as? MKClusterAnnotation {
                let id = "TripCluster"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id)
                            ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id))
                view.annotation = cluster
                view.canShowCallout = false

                // Use the first member's photo for the cluster pin
                let memberPhoto = (cluster.memberAnnotations.first as? TripAnnotation)?.photo
                let pinW: CGFloat = 64
                let pinH: CGFloat = 48
                let pinImage = renderClusterPinImage(
                    photo: memberPhoto,
                    count: cluster.memberAnnotations.count,
                    pinWidth: pinW, pinHeight: pinH
                )
                view.image = pinImage
                let imgSize = pinImage.size
                view.frame.size = imgSize
                view.centerOffset = CGPoint(x: 0, y: -imgSize.height / 2)

                let dist = mapView.camera.centerCoordinateDistance
                let scale: CGFloat = dist > 2_000_000 ? 0.55 : dist > 500_000 ? 0.7 : dist > 100_000 ? 0.85 : 1.0
                view.transform = CGAffineTransform(scaleX: scale, y: scale)
                return view
            }

            guard let trip = annotation as? TripAnnotation else { return nil }
            let id = "TripPinpoint"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id)
                        ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id))
            view.annotation = trip
            view.canShowCallout = false
            view.clusteringIdentifier = "TripCluster"

            let pinW: CGFloat = 64
            let pinH: CGFloat = 48
            let pinImage = renderPinImage(photo: trip.photo, pinWidth: pinW, pinHeight: pinH)
            view.image = pinImage
            let imgSize = pinImage.size
            view.frame.size = imgSize
            view.centerOffset = CGPoint(x: 0, y: -imgSize.height / 2)

            // Scale down when zoomed out
            let dist = mapView.camera.centerCoordinateDistance
            let scale: CGFloat = dist > 2_000_000 ? 0.55 : dist > 500_000 ? 0.7 : dist > 100_000 ? 0.85 : 1.0
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
            return view
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Rescale pins based on zoom level
            let dist = mapView.camera.centerCoordinateDistance
            let scale: CGFloat = dist > 2_000_000 ? 0.55 : dist > 500_000 ? 0.7 : dist > 100_000 ? 0.85 : 1.0
            for annotation in mapView.annotations {
                if let view = mapView.view(for: annotation),
                   (annotation is TripAnnotation || annotation is MKClusterAnnotation) {
                    UIView.animate(withDuration: 0.2) {
                        view.transform = CGAffineTransform(scaleX: scale, y: scale)
                    }
                }
            }

            // Clear route overlay when user zooms out past ~500km
            if mapView.camera.centerCoordinateDistance > 500_000
                && !viewModel.activeRouteCoordinates.isEmpty {
                viewModel.clearRouteOverlay()
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            print("[Globe] didSelect annotation: \(type(of: view.annotation))")
            // Home pin — let MKMapView show the native callout; no further action.
            if view.annotation is HomeAnnotation { print("[Globe] HomeAnnotation — ignoring"); return }

            // Cluster tap — zoom in, then open sheet for the country
            if let cluster = view.annotation as? MKClusterAnnotation {
                print("[Globe] ClusterAnnotation tapped: \(cluster.memberAnnotations.count) members")
                mapView.deselectAnnotation(view.annotation, animated: false)
                spawnRipples(on: view)

                // Compute bounding rect of all member annotations with padding
                var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0
                for member in cluster.memberAnnotations {
                    let c = member.coordinate
                    minLat = min(minLat, c.latitude)
                    maxLat = max(maxLat, c.latitude)
                    minLon = min(minLon, c.longitude)
                    maxLon = max(maxLon, c.longitude)
                }
                // Zoom to show all members with generous padding
                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLon + maxLon) / 2
                )
                let camera = MKMapCamera(
                    lookingAtCenter: center,
                    fromDistance: 80_000,
                    pitch: 0,
                    heading: 0
                )
                mapView.setCamera(camera, animated: true)

                // After zoom, open sheet for the first trip's country
                if let firstTrip = cluster.memberAnnotations.first as? TripAnnotation {
                    let cityName = firstTrip.cityName
                    let countryCode = firstTrip.countryCode
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                        print("[Globe] Presenting sheet from cluster: city=\(cityName) country=\(countryCode)")
                        self.viewModel.selectedInitialCity = cityName
                        self.viewModel.animateToCountry(code: countryCode)
                    }
                }
                return
            }

            guard let trip = view.annotation as? TripAnnotation else { print("[Globe] Not a TripAnnotation — ignoring"); return }
            print("[Globe] TripAnnotation tapped: city=\(trip.cityName) country=\(trip.countryCode)")
            mapView.deselectAnnotation(view.annotation, animated: false)

            // --- Ripple ping animation on the pin ---
            spawnRipples(on: view)

            // --- Zoom tight into the city (street-level, top-down) ---
            let camera = MKMapCamera(
                lookingAtCenter: trip.coordinate,
                fromDistance: 30_000,
                pitch: 0,
                heading: 0
            )
            mapView.setCamera(camera, animated: true)

            // --- Fetch route data and draw polyline overlay ---
            if let tripDoc = viewModel.trips.first(where: { $0.id == trip.tripID }) {
                Task {
                    await self.viewModel.loadRouteOverlay(for: tripDoc)
                }
            }

            // Show detail sheet after zoom settles
            let cityName = trip.cityName
            let countryCode = trip.countryCode
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                print("[Globe] Presenting sheet: city=\(cityName) country=\(countryCode)")
                self.viewModel.selectedInitialCity = cityName
                self.viewModel.animateToCountry(code: countryCode)
                print("[Globe] showCountryDetail=\(self.viewModel.showCountryDetail) selectedCountryCode=\(String(describing: self.viewModel.selectedCountryCode))")
            }
        }

        /// Spawn concentric ripple rings expanding outward from the pin.
        private func spawnRipples(on pinView: MKAnnotationView) {
            let rippleCount = 3
            for i in 0..<rippleCount {
                let ripple = UIView()
                ripple.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
                ripple.center = CGPoint(x: pinView.bounds.midX, y: pinView.bounds.midY)
                ripple.layer.cornerRadius = 10
                ripple.layer.borderWidth = 2.5
                ripple.layer.borderColor = UIColor(hex: 0xC8D7F3).cgColor
                ripple.backgroundColor = .clear
                ripple.alpha = 0.9
                pinView.addSubview(ripple)

                let delay = Double(i) * 0.25
                UIView.animate(
                    withDuration: 1.2,
                    delay: delay,
                    options: [.curveEaseOut],
                    animations: {
                        ripple.transform = CGAffineTransform(scaleX: 8, y: 8)
                        ripple.alpha = 0
                    },
                    completion: { _ in
                        ripple.removeFromSuperview()
                    }
                )
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // Country-area tap removed — use city pin taps to explore trips
        }
    }
}

// MARK: - GlobeView

@MainActor
struct GlobeView: View {
    @State private var viewModel = GlobeViewModel()
    @Environment(LocationManager.self) private var locationManager
    @Environment(\.modelContext) private var modelContext

    // Trip recording state
    @State private var showNameAlert = false
    @State private var activeTripId: String?
    @State private var recordingStartDate: Date?

    var body: some View {
        ZStack {
            Color.Nomad.globeBackground
                .ignoresSafeArea()

            GlobeMapView(
                viewModel: viewModel,
                onTapCountry: { code in
                    viewModel.animateToCountry(code: code)
                },
                homeCityCoordinate: viewModel.homeCityCoordinate,
                homeCityName: viewModel.homeCityName,
                tripPhotos: viewModel.tripPhotos,
                activeRouteCoordinates: viewModel.activeRouteCoordinates
            )
            .ignoresSafeArea()
            .sheet(isPresented: $viewModel.showProfileSheet) {
                ProfileSheet(
                    trips: viewModel.trips,
                    scrollToTripId: viewModel.scrollToTripId,
                    onStartTrip: {
                        // TRIP-01: Generate UUID, start recording
                        let tripId = UUID().uuidString
                        activeTripId = tripId
                        recordingStartDate = Date()
                        locationManager.startRecording(tripId: tripId)
                        // End any stale Live Activity before starting a new one.
                        Task {
                            for activity in Activity<TripActivityAttributes>.activities {
                                await activity.end(nil, dismissalPolicy: .immediate)
                            }
                        }
                        locationManager.startLiveActivity()
                    },
                    onDeleteTrip: { trip in
                        viewModel.deleteTrip(trip)
                        let tripId = trip.id
                        let descriptor = FetchDescriptor<RoutePoint>(
                            predicate: #Predicate<RoutePoint> { $0.tripId == tripId }
                        )
                        if let points = try? modelContext.fetch(descriptor) {
                            for point in points {
                                modelContext.delete(point)
                            }
                            try? modelContext.save()
                        }
                    },
                    countries: viewModel.countries,
                    homeCityName: viewModel.homeCityName,
                    friendPosts: viewModel.friendPosts
                )
            }
            .sheet(isPresented: $viewModel.showCountryDetail, onDismiss: {
                viewModel.showProfileSheet = true
            }) {
                if let code = viewModel.selectedCountryCode {
                    let countryTrips = viewModel.trips.filter {
                        $0.visitedCountryCodes.contains(code)
                    }
                    CountryDetailSheet(
                        countryCode: code,
                        trips: countryTrips,
                        initialCityName: viewModel.selectedInitialCity,
                        onDeleteTrip: { trip in
                            viewModel.deleteTrip(trip)
                            // Purge local SwiftData RoutePoint records for the deleted trip
                            let tripId = trip.id
                            let descriptor = FetchDescriptor<RoutePoint>(
                                predicate: #Predicate<RoutePoint> { $0.tripId == tripId }
                            )
                            if let points = try? modelContext.fetch(descriptor) {
                                for point in points {
                                    modelContext.delete(point)
                                }
                                try? modelContext.save()
                            }
                        }
                    )
                }
            }

            // Recording pill — conditionally present in view hierarchy when recording.
            // T-03-09: Removed from hierarchy (not just hidden) so timer is cancelled.
            if locationManager.isRecording {
                RecordingPill(onStopTrip: { showNameAlert = true })
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    .zIndex(1)
            }

        }
        .task {
            // One-time dummy data seed — remove this block when done demoing
            if !UserDefaults.standard.bool(forKey: "dummyDataSeeded") {
                await DummyDataSeeder.seed()
                UserDefaults.standard.set(true, forKey: "dummyDataSeeded")
            }
            await viewModel.loadGlobeData()
            locationManager.configure(modelContext: modelContext)
        }
        .onChange(of: showNameAlert) { _, show in
            if show {
                presentTripNameAlert()
            }
        }
    }

    // MARK: - Trip Name Alert

    /// Present UIAlertController with text field for trip naming (D-05).
    /// UIAlertController used (not SwiftUI .alert) to support text field with disable-until-populated Save button.
    private func presentTripNameAlert() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            showNameAlert = false
            return
        }

        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }

        let alert = UIAlertController(
            title: "Name Your Trip",
            message: "Give this trip a name to save it.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "e.g. Afternoon in Shibuya"
        }

        let saveAction = UIAlertAction(title: "Save Trip", style: .default) { [weak alert] _ in
            let name = alert?.textFields?.first?.text ?? ""
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            Task { @MainActor in
                await self.saveTrip(name: name)
            }
        }
        saveAction.isEnabled = false  // Disabled until text field has content
        alert.addAction(saveAction)

        let discardAction = UIAlertAction(title: "Discard Trip", style: .destructive) { _ in
            Task { @MainActor in
                self.discardTrip()
            }
        }
        alert.addAction(discardAction)

        // Enable Save only when text is non-empty
        // Use nonisolated(unsafe) to suppress Swift 6 Sendable warning for UIKit notification callback
        let textField = alert.textFields?.first
        NotificationCenter.default.addObserver(
            forName: UITextField.textDidChangeNotification,
            object: textField,
            queue: .main
        ) { [weak textField] _ in
            MainActor.assumeIsolated {
                let text = textField?.text ?? ""
                saveAction.isEnabled = !text.trimmingCharacters(in: .whitespaces).isEmpty
            }
        }

        topVC.present(alert, animated: true) {
            self.showNameAlert = false
        }
    }

    // MARK: - Trip Lifecycle

    /// Finalize trip: fetch route points, stop recording, query HealthKit, call TripService.
    private func saveTrip(name: String) async {
        guard let tripId = activeTripId,
              let uid = Auth.auth().currentUser?.uid else { return }

        let routePoints = locationManager.fetchUnsyncedPoints(tripId: tripId)
        locationManager.stopRecording()
        await locationManager.endLiveActivity()

        let startDate = recordingStartDate ?? Date()
        let endDate = Date()

        // Query HealthKit for step count (TRIP-05)
        let steps = await queryStepCount(start: startDate, end: endDate)

        // Calculate distance from route points
        let distance = calculateDistance(from: routePoints)

        // Reverse-geocode the actual city from the first route point
        var locality = name
        if let firstPoint = routePoints.first {
            let location = CLLocation(latitude: firstPoint.latitude, longitude: firstPoint.longitude)
            if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
               let city = placemarks.first?.locality {
                locality = city
            }
        }

        let tripService = TripService()
        do {
            try await tripService.finalizeTrip(
                userId: uid,
                tripId: tripId,
                cityName: name,
                locality: locality,
                startDate: startDate,
                endDate: endDate,
                routePoints: routePoints,
                stepCount: steps,
                distanceMeters: distance
            )
            locationManager.markPointsSynced(routePoints)

            // Update visited countries so globe highlights the new country (Success Criterion 6)
            // TripService.finalizeTrip already detects codes internally; derive them from route points
            let coords = routePoints.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
            var countryCodes: [String] = []
            let geocoder = CLGeocoder()
            let sampleIndices = [0, coords.count / 2, coords.count - 1].filter { $0 < coords.count }
            for idx in sampleIndices {
                if let placemarks = try? await geocoder.reverseGeocodeLocation(coords[idx]),
                   let code = placemarks.first?.isoCountryCode,
                   !countryCodes.contains(code) {
                    countryCodes.append(code)
                }
            }
            if !countryCodes.isEmpty {
                try await tripService.updateUserVisitedCountries(userId: uid, newCodes: countryCodes)
            }

            // Refresh globe data to show the new trip and updated country highlights
            await viewModel.loadGlobeData()
        } catch {
            print("[Trip] Finalization error: \(error)")
        }

        activeTripId = nil
        recordingStartDate = nil
    }

    /// Discard trip: stop recording and purge SwiftData route points.
    /// Uses the existing modelContext property declared above (no duplicate declaration).
    private func discardTrip() {
        guard let tripId = activeTripId else { return }
        locationManager.stopRecording()
        Task {
            await locationManager.endLiveActivity()
        }
        let descriptor = FetchDescriptor<RoutePoint>(
            predicate: #Predicate<RoutePoint> { $0.tripId == tripId }
        )
        if let points = try? modelContext.fetch(descriptor) {
            for point in points {
                modelContext.delete(point)
            }
            try? modelContext.save()
        }
        activeTripId = nil
        recordingStartDate = nil
    }

    // MARK: - HealthKit Step Count

    /// Query cumulative step count from HealthKit for the trip duration (TRIP-05).
    private func queryStepCount(start: Date, end: Date) async -> Int {
        let healthStore = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable(),
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
        } catch { return 0 }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let steps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Distance Calculation

    /// Calculate total route distance in meters from GPS route points.
    private func calculateDistance(from points: [RoutePoint]) -> Double {
        guard points.count > 1 else { return 0 }
        var total: Double = 0
        for i in 1..<points.count {
            let prev = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let curr = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            total += curr.distance(from: prev)
        }
        return total
    }
}
