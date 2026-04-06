import SwiftData
import CoreLocation

// RoutePoint — SwiftData model for GPS point buffering.
// D-16: Local buffer before Firestore sync. isSynced flag tracks upload state.
// Written by LocationManager (Plan 03), read by TripService (Plan 04) for batch upload.

@Model
final class RoutePoint {
    var tripId: String
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var accuracy: Double
    var altitude: Double
    var isSynced: Bool

    init(tripId: String, location: CLLocation) {
        self.tripId = tripId
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp
        self.accuracy = location.horizontalAccuracy
        self.altitude = location.altitude
        self.isSynced = false
    }
}
