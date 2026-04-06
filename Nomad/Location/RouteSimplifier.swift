import CoreLocation

// RouteSimplifier — Ramer-Douglas-Peucker route simplification.
// LOC-04: Reduces GPS trace to ~500pt detail array (epsilon 10m) and ~50pt preview array (epsilon 50m).
// Output format: [[Double]] (lat/lon pairs) ready for Firestore routeDetail and routePreview fields (D-14).
// Pure algorithm — no side effects, no external dependencies beyond CoreLocation.

enum RouteSimplifier {
    /// Simplify a GPS trace using the Ramer-Douglas-Peucker algorithm.
    /// - Parameters:
    ///   - points: Raw GPS coordinates in recording order.
    ///   - epsilon: Distance tolerance in meters. Use ~10 for detail (~500pt), ~50 for preview (~50pt).
    /// - Returns: Simplified coordinate array preserving route shape within epsilon tolerance.
    static func simplify(_ points: [CLLocationCoordinate2D], epsilon: Double) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }

        var maxDistance = 0.0
        var maxIndex = 0

        let first = points.first!
        let last = points.last!

        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(point: points[i], lineStart: first, lineEnd: last)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        if maxDistance > epsilon {
            let left = simplify(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = simplify(Array(points[maxIndex...]), epsilon: epsilon)
            return Array(left.dropLast()) + right
        } else {
            return [first, last]
        }
    }

    /// Convert RoutePoint SwiftData models to CLLocationCoordinate2D array.
    static func coordinatesFromRoutePoints(_ points: [RoutePoint]) -> [CLLocationCoordinate2D] {
        points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// Convenience: produce both detail and preview arrays from raw route points.
    /// - Parameter rawPoints: SwiftData RoutePoint records in recording order.
    /// - Returns: Tuple of detail (~500pt, epsilon 10m) and preview (~50pt, epsilon 50m) arrays.
    ///            Both arrays are [[lat, lon]] ready for Firestore field storage.
    static func simplifyRoute(_ rawPoints: [RoutePoint]) -> (detail: [[Double]], preview: [[Double]]) {
        let coordinates = coordinatesFromRoutePoints(rawPoints)

        // Detail: epsilon 10m targets ~200-500 points depending on trip length.
        let detailCoords = simplify(coordinates, epsilon: 10.0)
        // Preview: epsilon 50m targets ~50 points for globe/card display.
        let previewCoords = simplify(coordinates, epsilon: 50.0)

        let detail = detailCoords.map { [$0.latitude, $0.longitude] }
        let preview = previewCoords.map { [$0.latitude, $0.longitude] }

        return (detail: detail, preview: preview)
    }

    // MARK: - Private

    /// Perpendicular distance from a point to a line segment, in meters.
    /// Uses CLLocation.distance(from:) for meter-accurate Haversine calculation.
    private static func perpendicularDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let pLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let startLoc = CLLocation(latitude: lineStart.latitude, longitude: lineStart.longitude)
        let endLoc = CLLocation(latitude: lineEnd.latitude, longitude: lineEnd.longitude)

        let lineLength = startLoc.distance(from: endLoc)
        guard lineLength > 0 else { return pLoc.distance(from: startLoc) }

        // Project point onto line segment using dot product, clamped to [0, 1].
        let t = max(0, min(1, dotProduct(point, lineStart, lineEnd) / (lineLength * lineLength)))
        let projLat = lineStart.latitude + t * (lineEnd.latitude - lineStart.latitude)
        let projLon = lineStart.longitude + t * (lineEnd.longitude - lineStart.longitude)
        let projLoc = CLLocation(latitude: projLat, longitude: projLon)

        return pLoc.distance(from: projLoc)
    }

    private static func dotProduct(
        _ p: CLLocationCoordinate2D,
        _ lineStart: CLLocationCoordinate2D,
        _ lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude
        let px = p.longitude - lineStart.longitude
        let py = p.latitude - lineStart.latitude
        return px * dx + py * dy
    }
}
