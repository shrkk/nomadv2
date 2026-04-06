import SwiftUI
import MapKit

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
                    scrollToTripId: viewModel.scrollToTripId
                )
            }
        }
        .task {
            await viewModel.loadGlobeData()
            locationManager.configure(modelContext: modelContext)
        }
    }
}
