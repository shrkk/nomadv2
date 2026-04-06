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
        // Respond to viewModel-driven camera changes
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onTapCountry: onTapCountry)
    }

    @MainActor
    class Coordinator: NSObject, MKMapViewDelegate {
        let viewModel: GlobeViewModel
        let onTapCountry: (String) -> Void
        var mapView: MKMapView?

        init(viewModel: GlobeViewModel, onTapCountry: @escaping (String) -> Void) {
            self.viewModel = viewModel
            self.onTapCountry = onTapCountry
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = mapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // Find nearest visited country
            let visitedCodes = GlobeCountryOverlay.hardcodedVisitedCodes
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
                    selectedTrip: viewModel.selectedTrip,
                    trips: GlobePinpoint.StubTrip.stubTrips
                )
            }
        }
        .task {
            await viewModel.loadGlobeData()
        }
    }
}
