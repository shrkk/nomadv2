import CoreLocation
import SwiftData
import Observation

// LocationManager — background GPS recording pipeline.
// LOC-01: Uses CLBackgroundActivitySession to keep GPS alive when backgrounded.
// LOC-02: Uses CLLocationUpdate.liveUpdates() async stream (iOS 17+).
// LOC-03: Writes RoutePoint records to SwiftData with isSynced=false for Firestore batch upload.
// T-02-12: Accuracy filter < 50m reduces battery drain from low-quality fixes.

@Observable
@MainActor
final class LocationManager: NSObject {
    var isRecording = false
    var currentTripId: String?

    // CRITICAL: Must be a stored property, NOT a local variable.
    // If CLBackgroundActivitySession is deallocated, background GPS silently stops.
    private var backgroundSession: CLBackgroundActivitySession?
    private var recordingTask: Task<Void, Never>?
    private var modelContext: ModelContext?

    /// Call once at app startup to provide the shared ModelContext.
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Start background GPS recording for a trip.
    func startRecording(tripId: String) {
        guard !isRecording else { return }
        isRecording = true
        currentTripId = tripId

        // Retain CLBackgroundActivitySession for entire recording duration.
        backgroundSession = CLBackgroundActivitySession()

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
        recordingTask?.cancel()
        recordingTask = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        isRecording = false
        currentTripId = nil
    }

    /// Save a GPS point to SwiftData local buffer.
    private func saveRoutePoint(location: CLLocation, tripId: String) async {
        await MainActor.run {
            guard let context = modelContext else { return }
            let point = RoutePoint(tripId: tripId, location: location)
            context.insert(point)
            try? context.save()
        }
    }

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
