import SwiftData
import Foundation

// TripLocal — SwiftData model for local trip state before Firestore sync.
// Holds active trip metadata. isSynced flag indicates Firestore upload completion.
// isActive flag distinguishes in-progress trips from completed ones.

@Model
final class TripLocal {
    var tripId: String
    var cityName: String
    var startDate: Date
    var endDate: Date?
    var isActive: Bool
    var isSynced: Bool

    init(tripId: String, cityName: String = "", startDate: Date = .now) {
        self.tripId = tripId
        self.cityName = cityName
        self.startDate = startDate
        self.endDate = nil
        self.isActive = true
        self.isSynced = false
    }
}
