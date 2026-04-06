import CoreLocation
import UserNotifications
import Observation

// VisitMonitor — CLVisit and geofence-based trip auto-detection.
// LOC-05: Monitors CLVisit departure events (system-batched, power-efficient).
// LOC-06: Home city geofence exit triggers local notification to prompt trip logging.
// TRIP-02: Geofence exit triggers sendTripStartNotification (guarded by manualOnlyMode).
// TRIP-03: After 3 dismissed notifications, manualOnlyMode=true is set by AppDelegate;
//          handleGeofenceExit() guards on this flag before sending any notification.
// D-09: manualOnlyMode stored in UserDefaults; checked on every geofence exit.
// D-10: Notification category "tripPromptCategory" with .customDismissAction enables
//       UNNotificationDismissActionIdentifier to fire in AppDelegate dismiss counter.

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

        // Register notification category before requesting permission so category is available
        // when the first notification is delivered.
        registerNotificationCategory()

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

    // MARK: - Private

    private func handleGeofenceExit() {
        // TRIP-03: Check manualOnlyMode before sending any notification.
        // Set to true by AppDelegate after 3 dismissed trip prompt notifications.
        guard !UserDefaults.standard.bool(forKey: "manualOnlyMode") else { return }

        let scope = UserDefaults.standard.string(forKey: "discoveryScope") ?? "everywhere"
        _ = scope  // Both scopes prompt on departure — geofence exit IS the trigger
        sendTripStartNotification()
    }

    private func sendTripStartNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Adventure detected!"
        content.body = "Looks like you're exploring somewhere new. Start logging this trip?"
        content.sound = .default
        // D-10: Set category so UNNotificationDismissActionIdentifier fires in AppDelegate
        content.categoryIdentifier = "tripPromptCategory"

        let request = UNNotificationRequest(
            identifier: "tripStartPrompt-\(UUID().uuidString)",
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Register "tripPromptCategory" with .customDismissAction so dismiss events reach AppDelegate.
    /// D-10: Without .customDismissAction, UNNotificationDismissActionIdentifier does not fire.
    /// Call once from startMonitoring() before any notifications are delivered.
    private func registerNotificationCategory() {
        let category = UNNotificationCategory(
            identifier: "tripPromptCategory",
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction  // Required for dismiss counter in AppDelegate
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
