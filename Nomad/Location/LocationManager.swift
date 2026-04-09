import ActivityKit
import CoreLocation
import SwiftData
import Observation

// LocationManager — background GPS recording pipeline.
// LOC-01: Uses CLBackgroundActivitySession to keep GPS alive when backgrounded.
// LOC-02: Uses CLLocationUpdate.liveUpdates() async stream (iOS 17+).
// LOC-03: Writes RoutePoint records to SwiftData with isSynced=false for Firestore batch upload.
// T-02-12: Accuracy filter < 50m reduces battery drain from low-quality fixes.
// T-03.2-05: Live Activity update timer fires every 30s; geocode throttled to 60s intervals.

@Observable
@MainActor
final class LocationManager: NSObject {
    var isRecording = false
    var currentTripId: String?

    // MARK: - Distance Accumulation (D-06)
    /// Accumulated GPS distance in meters for the current trip.
    var accumulatedDistanceMeters: Double = 0
    /// When the current recording session started (used for elapsed time in Live Activity).
    var recordingStartDate: Date?

    // MARK: - Private State
    // CRITICAL: Must be a stored property, NOT a local variable.
    // If CLBackgroundActivitySession is deallocated, background GPS silently stops.
    private var backgroundSession: CLBackgroundActivitySession?
    private var recordingTask: Task<Void, Never>?
    private var modelContext: ModelContext?

    /// Last accepted GPS fix — used to compute incremental distance between consecutive points.
    private var lastLocation: CLLocation?
    /// Timer that fires every 30s to push a Live Activity update (T-03.2-05).
    private var liveActivityUpdateTimer: Timer?
    /// Most recently reverse-geocoded city/neighborhood name (city-level only, no precise GPS).
    private var lastGeocodedLocationName: String = "Locating..."
    /// Last time CLGeocoder was called — throttled to at most once per 60 seconds.
    private var lastGeocodeTime: Date = .distantPast

    // MARK: - Configuration

    /// Call once at app startup to provide the shared ModelContext.
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Recording Lifecycle

    /// Start background GPS recording for a trip.
    func startRecording(tripId: String) {
        guard !isRecording else { return }
        isRecording = true
        currentTripId = tripId

        // Reset distance accumulation for new trip.
        accumulatedDistanceMeters = 0
        lastLocation = nil
        lastGeocodedLocationName = "Locating..."
        recordingStartDate = Date()

        // Retain CLBackgroundActivitySession for entire recording duration.
        backgroundSession = CLBackgroundActivitySession()

        // Push a Live Activity update every 30 seconds (T-03.2-05: not continuously).
        liveActivityUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateLiveActivity()
            }
        }

        recordingTask = Task {
            do {
                let updates = CLLocationUpdate.liveUpdates()
                for try await update in updates {
                    guard !Task.isCancelled else { break }
                    guard let location = update.location else { continue }
                    // Filter: only accept updates with horizontal accuracy < 50m.
                    guard location.horizontalAccuracy > 0,
                          location.horizontalAccuracy < 50 else { continue }
                    await self.saveRoutePoint(location: location, tripId: tripId)
                }
            } catch {
                // Location stream ended or was cancelled.
                await MainActor.run {
                    self.isRecording = false
                }
            }
        }
    }

    /// Stop recording and clean up background session.
    func stopRecording() {
        // Invalidate Live Activity update timer before stopping (T-03.2-05).
        liveActivityUpdateTimer?.invalidate()
        liveActivityUpdateTimer = nil

        recordingTask?.cancel()
        recordingTask = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        isRecording = false
        currentTripId = nil

        // Reset distance accumulation.
        accumulatedDistanceMeters = 0
        lastLocation = nil
        recordingStartDate = nil
    }

    // MARK: - Live Activity Integration (D-06)

    /// Request a new ActivityKit Live Activity for the active trip.
    /// Caller must end any stale activities before calling this (see GlobeView).
    func startLiveActivity() {
        let initialState = TripActivityAttributes.ContentState(
            distanceKm: 0,
            elapsedSeconds: 0,
            locationName: "Locating...",
            isRecording: true
        )
        let attributes = TripActivityAttributes()
        do {
            _ = try Activity<TripActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: nil  // local-only — no push tokens for v1
            )
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    /// End all active TripActivityAttributes Live Activities with final stats.
    func endLiveActivity() async {
        let finalState = TripActivityAttributes.ContentState(
            distanceKm: accumulatedDistanceMeters / 1000.0,
            elapsedSeconds: Int(Date().timeIntervalSince(recordingStartDate ?? Date())),
            locationName: lastGeocodedLocationName,
            isRecording: false
        )
        for activity in Activity<TripActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }

    // MARK: - Private Helpers

    /// Push the current trip stats to all active TripActivityAttributes Live Activities.
    private func updateLiveActivity() {
        guard isRecording, let startDate = recordingStartDate else { return }
        let elapsed = Int(Date().timeIntervalSince(startDate))
        let state = TripActivityAttributes.ContentState(
            distanceKm: accumulatedDistanceMeters / 1000.0,
            elapsedSeconds: elapsed,
            locationName: lastGeocodedLocationName,
            isRecording: true
        )
        Task {
            for activity in Activity<TripActivityAttributes>.activities {
                await activity.update(
                    ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))
                )
            }
        }
    }

    /// Save a GPS point to SwiftData local buffer and accumulate distance.
    private func saveRoutePoint(location: CLLocation, tripId: String) async {
        await MainActor.run {
            guard let context = modelContext else { return }
            let point = RoutePoint(tripId: tripId, location: location)
            context.insert(point)
            try? context.save()

            // Accumulate distance from last accepted GPS fix.
            if let last = lastLocation {
                accumulatedDistanceMeters += location.distance(from: last)
            }
            lastLocation = location
        }

        // Throttled reverse geocode: at most once every 60 seconds (T-03.2-05).
        // City-level name only (locality) — no precise GPS coordinates exposed (T-03.2-03).
        if Date().timeIntervalSince(lastGeocodeTime) > 60 {
            lastGeocodeTime = Date()
            Task {
                let geocoder = CLGeocoder()
                if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
                   let placemark = placemarks.first {
                    let name = placemark.locality
                        ?? placemark.subLocality
                        ?? placemark.administrativeArea
                        ?? "Unknown"
                    await MainActor.run {
                        self.lastGeocodedLocationName = String(name.prefix(30))
                    }
                }
            }
        }
    }

    // MARK: - SwiftData Helpers

    /// Fetch all unsynced route points for a trip from SwiftData.
    func fetchUnsyncedPoints(tripId: String) -> [RoutePoint] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<RoutePoint>(
            predicate: #Predicate<RoutePoint> { point in
                point.tripId == tripId && point.isSynced == false
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Mark points as synced after successful Firestore write.
    func markPointsSynced(_ points: [RoutePoint]) {
        for point in points {
            point.isSynced = true
        }
        try? modelContext?.save()
    }
}
