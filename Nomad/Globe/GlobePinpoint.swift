import RealityKit
import UIKit

// MARK: - GlobePinpoint
//
// Helper to create pinpoint entities positioned on the globe sphere surface.
// Visual spec: 20pt amber (#E8A44A) sphere, 44pt hit area per Apple HIG.
// Source: UI-SPEC Globe Environment, Spacing Scale (touch target rule).

struct GlobePinpoint {

    // MARK: - Stub Trip Data

    /// Stub trip data for Phase 1 hardcoded pinpoints.
    struct StubTrip: Identifiable {
        let id: String
        let cityName: String
        let countryCode: String  // ISO_A2
        let latitude: Double
        let longitude: Double
        let dateLabel: String

        // STUB: Phase 1 only — replaced by Firestore trip models in Phase 2+
        static let stubTrips: [StubTrip] = [
            StubTrip(id: "trip-tokyo",   cityName: "Tokyo",           countryCode: "JP", latitude:  35.6762, longitude:  139.6503, dateLabel: "March 2026"),
            StubTrip(id: "trip-paris",   cityName: "Paris",           countryCode: "FR", latitude:  48.8566, longitude:    2.3522, dateLabel: "February 2026"),
            StubTrip(id: "trip-nairobi", cityName: "Nairobi",         countryCode: "KE", latitude:  -1.2921, longitude:   36.8219, dateLabel: "January 2026"),
            StubTrip(id: "trip-sydney",  cityName: "Sydney",          countryCode: "AU", latitude: -33.8688, longitude:  151.2093, dateLabel: "December 2025"),
            StubTrip(id: "trip-rio",     cityName: "Rio de Janeiro",  countryCode: "BR", latitude: -22.9068, longitude:  -43.1729, dateLabel: "November 2025"),
        ]
    }

    // MARK: - Sphere Position

    /// Converts latitude/longitude to a 3D position on the sphere surface.
    /// Radius 0.505 = globe radius (0.5) + 0.005 offset so the dot sits on the surface.
    /// Coordinate system matches RealityKit: Y-up, right-handed.
    static func spherePosition(lat: Double, lon: Double, radius: Float = 0.505) -> SIMD3<Float> {
        let latRad = Float(lat * .pi / 180)
        let lonRad = Float(lon * .pi / 180)
        return SIMD3<Float>(
            radius * cos(latRad) * sin(lonRad),
            radius * sin(latRad),
            radius * cos(latRad) * cos(lonRad)
        )
    }

    // MARK: - Entity Factory

    /// Creates a pinpoint ModelEntity at the given trip's lat/lon.
    ///
    /// Visual: 0.012 radius sphere (~20pt visual size at default camera distance 2.0).
    /// Material: amber (#E8A44A), unlit so color is consistent regardless of scene lighting.
    /// Collision: sphere at 0.022 radius (~44pt hit area per Apple HIG) for tap detection.
    @MainActor
    static func createEntity(for trip: StubTrip) -> ModelEntity {
        let pinpoint = ModelEntity(
            mesh: .generateSphere(radius: 0.012),
            materials: [UnlitMaterial(
                color: UIColor(hex: 0x5E89DD)  // Periwinkle blue accent
            )]
        )
        pinpoint.position = spherePosition(lat: trip.latitude, lon: trip.longitude)
        pinpoint.name = trip.id  // Used for tap identification in SpatialTapGesture

        // Larger collision shape for 44pt hit area per Apple HIG
        pinpoint.components.set(CollisionComponent(
            shapes: [.generateSphere(radius: 0.022)],
            mode: .trigger,
            filter: .default
        ))
        return pinpoint
    }
}
