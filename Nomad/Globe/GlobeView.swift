import ActivityKit
import SwiftUI
import MapKit
import FirebaseAuth
import HealthKit
import SwiftData
import CoreLocation

// MARK: - GlobeMapView
//
// MKMapView with .hybridFlyover map type renders a true 3D globe with
// Apple Maps satellite imagery and location labels at max zoom-out.

@MainActor
struct GlobeMapView: UIViewRepresentable {
    let viewModel: GlobeViewModel
    let onTapCountry: (String) -> Void

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

        let newCodes = Set(viewModel.visitedCountryCodes)

        // Diff visitedCountryCodes: if the set changed, remove old overlays and re-add
        if newCodes != context.coordinator.cachedVisitedCodes {
            mapView.removeOverlays(mapView.overlays)
            context.coordinator.overlaysAdded = false
            context.coordinator.cachedVisitedCodes = newCodes
        }

        // Add overlays when countries AND visitedCountryCodes are both loaded
        if !context.coordinator.overlaysAdded && !newCodes.isEmpty {
            context.coordinator.overlaysAdded = true
            context.coordinator.addCountryOverlays(
                to: mapView,
                countries: viewModel.countries,
                visitedCodes: newCodes
            )
        }

        // Diff trip pinpoints: re-add when trip count changes
        let newTripCount = viewModel.trips.count
        if newTripCount != context.coordinator.cachedTripCount {
            // Remove existing pinpoint annotations
            let existing = mapView.annotations.filter { $0 is TripAnnotation }
            mapView.removeAnnotations(existing)
            context.coordinator.cachedTripCount = newTripCount
            context.coordinator.addPinpointAnnotations(to: mapView, trips: viewModel.trips)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onTapCountry: onTapCountry)
    }

    // MARK: - Trip Annotation

    class TripAnnotation: MKPointAnnotation {
        var tripID: String = ""
        var countryCode: String = ""
    }

    @MainActor
    class Coordinator: NSObject, MKMapViewDelegate {
        let viewModel: GlobeViewModel
        let onTapCountry: (String) -> Void
        var mapView: MKMapView?
        var overlaysAdded = false
        var cachedVisitedCodes: Set<String> = []
        var cachedTripCount: Int = -1

        init(viewModel: GlobeViewModel, onTapCountry: @escaping (String) -> Void) {
            self.viewModel = viewModel
            self.onTapCountry = onTapCountry
        }

        // MARK: - Overlay Setup

        func addCountryOverlays(to mapView: MKMapView, countries: [CountryFeature], visitedCodes: Set<String>) {
            for country in countries where visitedCodes.contains(country.isoCode) {
                for ring in country.polygons where ring.count >= 3 {
                    var coords = ring
                    let polygon = MKPolygon(coordinates: &coords, count: coords.count)
                    polygon.title = country.isoCode
                    mapView.addOverlay(polygon, level: .aboveRoads)
                }
            }
        }

        func addPinpointAnnotations(to mapView: MKMapView, trips: [TripDocument]) {
            for trip in trips {
                guard let coord = trip.coordinate else { continue }
                let annotation = TripAnnotation()
                annotation.coordinate = coord
                annotation.tripID = trip.id
                annotation.countryCode = trip.visitedCountryCodes.first ?? ""
                mapView.addAnnotation(annotation)
            }
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = UIColor(red: 0.910, green: 0.643, blue: 0.290, alpha: 0.45)
            renderer.strokeColor = UIColor(red: 0.910, green: 0.643, blue: 0.290, alpha: 0.8)
            renderer.lineWidth = 1.0
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let trip = annotation as? TripAnnotation else { return nil }
            let id = "TripPinpoint"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id)
                        ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id))
            view.annotation = trip
            view.canShowCallout = false

            let dotSize: CGFloat = 14
            let hitSize: CGFloat = 44
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: hitSize, height: hitSize))
            view.image = renderer.image { _ in
                let amber = UIColor(red: 0.910, green: 0.643, blue: 0.290, alpha: 1.0)
                amber.setFill()
                let offset = (hitSize - dotSize) / 2
                UIBezierPath(
                    ovalIn: CGRect(x: offset, y: offset, width: dotSize, height: dotSize)
                ).fill()
            }
            view.frame.size = CGSize(width: hitSize, height: hitSize)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let trip = view.annotation as? TripAnnotation else { return }
            mapView.deselectAnnotation(view.annotation, animated: false)
            viewModel.scrollToTripId = trip.tripID
            viewModel.showProfileSheet = true
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = mapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // Find nearest visited country using live visitedCountryCodes
            let visitedCodes = Set(viewModel.visitedCountryCodes)
            let visitedCountries = viewModel.countries.filter { visitedCodes.contains($0.isoCode) }

            var bestCode: String?
            var bestDist: Double = .infinity
            for country in visitedCountries {
                let coords = country.polygons.first ?? []
                guard !coords.isEmpty else { continue }
                let cLat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
                let cLon = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
                let dLat = coordinate.latitude - cLat
                let dLon = coordinate.longitude - cLon
                let dist = dLat * dLat + dLon * dLon
                if dist < bestDist {
                    bestDist = dist
                    bestCode = country.isoCode
                }
            }

            if let code = bestCode, bestDist < 1000 {
                onTapCountry(code)
            }
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
            Color.black
                .ignoresSafeArea()

            GlobeMapView(
                viewModel: viewModel,
                onTapCountry: { code in
                    viewModel.animateToCountry(code: code)
                }
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
                        viewModel.showProfileSheet = false
                        // End any stale Live Activity before starting a new one.
                        Task {
                            for activity in Activity<TripActivityAttributes>.activities {
                                await activity.end(nil, dismissalPolicy: .immediate)
                            }
                        }
                        locationManager.startLiveActivity()
                    }
                )
            }
            .sheet(isPresented: $viewModel.showCountryDetail) {
                if let code = viewModel.selectedCountryCode {
                    let countryTrips = viewModel.trips.filter {
                        $0.visitedCountryCodes.contains(code)
                    }
                    CountryDetailSheet(countryCode: code, trips: countryTrips)
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

            // Floating journey pill — hidden when country detail sheet is open
            if !viewModel.showProfileSheet && !viewModel.showCountryDetail {
                VStack {
                    Spacer()
                    JourneyPill(
                        onOpenJourneys: { viewModel.showProfileSheet = true },
                        onStartTrip: {
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
                        }
                    )
                    .padding(.bottom, 24)
                }
                .allowsHitTesting(true)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .task {
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
            // Accessing UIKit properties on main queue (queue: .main above)
            let text = textField?.text ?? ""
            DispatchQueue.main.async {
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

        let tripService = TripService()
        do {
            try await tripService.finalizeTrip(
                userId: uid,
                tripId: tripId,
                cityName: name,
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
