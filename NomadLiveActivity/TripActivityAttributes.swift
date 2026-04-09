import ActivityKit
import Foundation

// TripActivityAttributes — shared between the main app target and the NomadLiveActivity
// widget extension target. Add this file to BOTH target memberships in Xcode.
//
// T-03.2-03: ContentState exposes only generic distance/elapsed/city-level location —
// no precise GPS coordinates, no trip ID, no user ID are included.

struct TripActivityAttributes: ActivityAttributes {
    // No static properties — all trip data is dynamic and lives in ContentState.

    struct ContentState: Codable, Hashable {
        /// Kilometers covered so far, shown to 1 decimal place.
        var distanceKm: Double
        /// Seconds elapsed since trip recording started.
        var elapsedSeconds: Int
        /// Reverse-geocoded city/neighborhood name, max 30 chars.
        /// City-level only (CLGeocoder locality) — no precise GPS coordinates exposed.
        var locationName: String
        /// true while actively recording; false when trip is ended.
        var isRecording: Bool
    }
}
