import CoreLocation
import UserNotifications
import Observation

// VisitMonitor — CLVisit and geofence-based trip auto-detection.
// LOC-05: Monitors CLVisit departure events (system-batched, power-efficient).
// LOC-06: Home city geofence exit triggers local notification to prompt trip logging.
// Discovery scope "awayOnly" means geofence exit IS the trigger — suppression not needed
// since CLRegion exit only fires when the user physically leaves the geofence boundary.

@Observable
@MainActor
final class VisitMonitor: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    var isMonitoring = false

    override init() {
        super.init()
        locationManager.delegate = self
    }

    /// Start monitoring home city geofence exit + CLVisit.
    /// - Parameters:
    ///   - homeCityLatitude: Latitude of home city center.
    ///   - homeCityLongitude: Longitude of home city center.
    ///   - radius: Geofence radius in meters (default 50km covers metropolitan area).
    func startMonitoring(homeCityLatitude: Double, homeCityLongitude: Double, radius: Double = 50_000) {
        let center = CLLocationCoordinate2D(latitude: homeCityLatitude, longitude: homeCityLongitude)
        let region = CLCircularRegion(center: center, radius: radius, identifier: "homeCityGeofence")
        region.notifyOnEntry = false
        region.notifyOnExit = true

        locationManager.startMonitoring(for: region)
        locationManager.startMonitoringVisits()
        isMonitoring = true

        // Request notification permission for trip prompts.
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    func stopMonitoring() {
        let regions = locationManager.monitoredRegions
        for region in regions {
            locationManager.stopMonitoring(for: region)
        }
        locationManager.stopMonitoringVisits()
        isMonitoring = false
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == "homeCityGeofence" else { return }
        Task { @MainActor in
            self.handleGeofenceExit()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // Only handle CLVisit departure (departureDate == .distantFuture means still at venue).
        guard visit.departureDate != .distantFuture else { return }
        Task { @MainActor in
            self.handleGeofenceExit()
        }
    }

    private func handleGeofenceExit() {
        // Check discovery scope — geofence exit fires only when LEAVING home city.
        // Both "awayOnly" and "everywhere" scopes should prompt on departure.
        let scope = UserDefaults.standard.string(forKey: "discoveryScope") ?? "everywhere"
        // For "awayOnly": geofence exit IS the trigger — send notification.
        // For "everywhere": always send notification on detected departure.
        // Phase 3 will add the 3-dismiss counter logic (TRIP-03).
        _ = scope  // scope-aware behavior deferred to Phase 3
        sendTripStartNotification()
    }

    private func sendTripStartNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Adventure detected!"
        content.body = "Looks like you're exploring somewhere new. Start logging this trip?"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "tripStartPrompt-\(UUID().uuidString)",
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
