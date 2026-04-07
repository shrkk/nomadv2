import WeatherKit
import CoreLocation

// NomadWeatherService — stateless wrapper around Apple WeatherKit.
// Returns current temperature as a formatted string (e.g. "-8°C") or nil on error.
// T-3.1-02: All errors caught and returned as nil — no crash on WeatherKit unavailability.
// The UI hides the temperature pill when nil is returned.

@MainActor final class NomadWeatherService {
    static let shared = NomadWeatherService()

    private init() {}

    /// Fetches the current temperature for the given coordinate.
    /// - Returns: Formatted string like "-8°C", or nil if unavailable (network error, entitlement missing, etc.)
    func fetchTemperature(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let temperature = weather.currentWeather.temperature
            let value = Int(temperature.value.rounded())
            let symbol = temperature.unit.symbol
            return "\(value)°\(symbol)"
        } catch {
            return nil
        }
    }
}
