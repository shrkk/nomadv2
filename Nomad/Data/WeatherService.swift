import CoreLocation

// NomadWeatherService — temperature fetch wrapper.
// WeatherKit requires a paid Apple Developer account; returns nil on personal teams.
// The UI hides the temperature notch pill when nil is returned.

@MainActor final class NomadWeatherService {
    static let shared = NomadWeatherService()

    private init() {}

    /// Returns nil — WeatherKit entitlement not available on personal developer teams.
    /// Replace with WeatherKit implementation when building with a paid team.
    func fetchTemperature(for coordinate: CLLocationCoordinate2D) async -> String? {
        return nil
    }
}
