import SwiftUI
@preconcurrency import MapKit
import CoreLocation

// MARK: - VisitedPlace
//
// Represents a numbered stop on a trip route — displayed as an amber circle pin.
// index is 1-based visit order.

struct VisitedPlace {
    let coordinate: CLLocationCoordinate2D
    let index: Int  // 1-based visit order
}

// MARK: - NumberedAnnotation

final class NumberedAnnotation: MKPointAnnotation, @unchecked Sendable {
    let index: Int

    init(coordinate: CLLocationCoordinate2D, index: Int) {
        self.index = index
        super.init()
        self.coordinate = coordinate
    }
}

// MARK: - TripRouteMapView
//
// Non-interactive MapKit map showing full GPS trace (amber polyline) and
// numbered place pins in visit order. Lazy reverse-geocoding fires on pin tap.
// D-13: Non-interactive per UI-SPEC Map section.
// D-14: routePoints subcollection fetch provides full GPS trace.

struct TripRouteMapView: UIViewRepresentable {
    let routeCoordinates: [CLLocationCoordinate2D]
    let places: [VisitedPlace]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.mapType = .standard
        mapView.pointOfInterestFilter = .excludingAll
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        guard !routeCoordinates.isEmpty else { return }
        // Prevent duplicate overlays on SwiftUI re-render
        guard !context.coordinator.overlaysAdded else { return }
        context.coordinator.overlaysAdded = true

        // Add polyline trace
        var coords = routeCoordinates
        let polyline = MKPolyline(coordinates: &coords, count: coords.count)
        mapView.addOverlay(polyline)

        // Add numbered place pins
        for place in places {
            let annotation = NumberedAnnotation(coordinate: place.coordinate, index: place.index)
            mapView.addAnnotation(annotation)
        }

        // Auto-fit map to show full route with padding
        let padding = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: padding, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var overlaysAdded = false
        var geocodeCache: [String: String] = [:]
        var isGeocoding = false

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(hex: 0x5EE0DD)
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let numbered = annotation as? NumberedAnnotation else { return nil }

            let reuseId = "NumberedPin"
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)

            annotationView.annotation = annotation
            annotationView.canShowCallout = true

            // Draw white circle with dark number using UIGraphicsImageRenderer
            let size: CGFloat = 24
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            let image = renderer.image { _ in
                UIColor(hex: 0xC8D7F3).setFill()
                UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).fill()
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: UIColor(hex: 0x0F0F28)
                ]
                let text = "\(numbered.index)" as NSString
                let textSize = text.size(withAttributes: attrs)
                let textRect = CGRect(
                    x: (size - textSize.width) / 2,
                    y: (size - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                text.draw(in: textRect, withAttributes: attrs)
            }

            annotationView.image = image
            // Center the annotation image on the coordinate
            annotationView.centerOffset = CGPoint(x: 0, y: -size / 2)

            return annotationView
        }

        // MARK: - Lazy Geocoding on Pin Tap (T-03-12: geocode only on tap, cache results)

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let numbered = view.annotation as? NumberedAnnotation else { return }

            let key = "\(numbered.coordinate.latitude),\(numbered.coordinate.longitude)"

            // Return cached result immediately
            if let cached = geocodeCache[key] {
                numbered.title = cached
                return
            }

            // Only one geocode request at a time per CLGeocoder limitation
            guard !isGeocoding else { return }
            isGeocoding = true

            let location = CLLocation(
                latitude: numbered.coordinate.latitude,
                longitude: numbered.coordinate.longitude
            )

            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                let name = placemarks?.first?.name
                    ?? placemarks?.first?.locality
                    ?? "Unknown"
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.isGeocoding = false
                    self.geocodeCache[key] = name
                    numbered.title = name
                }
            }
        }
    }
}

// MARK: - TripRouteMapContainer
//
// Wraps TripRouteMapView in a 240pt clipped container (UI-SPEC map section).

struct TripRouteMapContainer: View {
    let routeCoordinates: [CLLocationCoordinate2D]
    let places: [VisitedPlace]
    let isLoading: Bool

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .background(Color.Nomad.panelBlack)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                TripRouteMapView(routeCoordinates: routeCoordinates, places: places)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
