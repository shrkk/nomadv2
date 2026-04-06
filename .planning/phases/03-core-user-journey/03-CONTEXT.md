# Phase 3: Core User Journey - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Assemble the full product loop a user experiences on every trip: the persistent profile panel shows real trip history from Firestore, the user can start a trip manually or accept an auto-detect prompt, an active recording indicator shows while logging, and tapping any trip opens the detail view with a Strava-style route map, matched photo gallery, and step count — all reading from the data pipeline built in Phase 2.

</domain>

<decisions>
## Implementation Decisions

### Profile Panel Access
- **D-01:** Floating drag strip (slim pill/handle) at the bottom of the globe view at all times. User drags up or taps to open ProfileSheet. Behaves like iOS Control Center pull-up — native feel, globe always visible as backdrop.
- **D-02:** The strip is persistent across the entire app — it floats above GlobeView and is never hidden (even during active recording). The globe is always the backdrop.

### Trip Card Route Preview
- **D-03:** Route shape drawn as a SwiftUI `Path`/`Shape` from the `routePreview` 50-pt lat/lon array. Lightweight — no MapKit view per card. Route renders as an amber line on a dark or cream background strip inside the card. Guaranteed smooth scroll performance.
- **D-04:** Coordinate normalization: scale lat/lon pairs to fit the card's bounding box before drawing the Path (subtract min, divide by range, multiply by view size).

### Trip Start + Naming Flow
- **D-05:** "+" tapped → recording starts immediately (no upfront prompt). User explores freely. When they tap Stop on the active trip pill, a name dialog appears. User enters a name → `TripService.finalizeTrip()` is called. Trip name is a required field before finalization.
- **D-06:** A temporary `tripId` (UUID) is generated at recording start and stored on `LocationManager.currentTripId`. This is the ID used for all local SwiftData writes and for the eventual Firestore write.

### Active Trip Indicator
- **D-07:** Floating pill overlaid on the globe during recording. Shows: pulsing red dot + "Recording — Xh Xm" elapsed timer + "Stop" button. Timer ticks every second using a `Timer.publish`. Pill anchored to top-center of the screen (below safe area / Dynamic Island), stays above the drag strip.
- **D-08:** Tapping "Stop" on the pill triggers the name dialog (D-05 flow). The pill disappears after the trip is finalized.

### Auto-Detect Dismiss Counter
- **D-09:** `VisitMonitor` tracks dismiss count in `UserDefaults` under key `"tripPromptDismissCount"`. After 3 dismissals, `VisitMonitor.stopMonitoring()` is called and `UserDefaults.standard.set(true, forKey: "manualOnlyMode")` is written. `VisitMonitor` checks this flag before sending any future notifications.
- **D-10:** The dismiss increment is triggered from the notification response handler (user taps "Dismiss" or swipes the notification away without tapping the action). Manual-only mode is permanent unless reset in settings (out of scope for this phase).

### Globe Real Data Wiring
- **D-11:** `GlobeViewModel` fetches trips from `users/{uid}/trips` Firestore collection on appear. Replaces `GlobePinpoint.StubTrip.stubTrips` stub with real `[TripDocument]` model. Uses `visitedCountryCodes` from the user document to drive country highlighting (replaces `GlobeCountryOverlay.hardcodedVisitedCodes`).
- **D-12:** Tapping a globe pinpoint opens ProfileSheet scrolled to that trip (matching by `tripId`). ProfileSheet receives the trip list + a `scrollToTripId` parameter.

### Trip Detail Map
- **D-13:** Full GPS trace fetched from `users/{uid}/trips/{tripId}/routePoints` subcollection on TripDetailSheet appear. Rendered as a `MKPolyline` overlay on a non-interactive `MKMapView` (interaction disabled — the map is purely visual, not a navigation interface). Amber stroke, 3pt line width.
- **D-14:** Place pins are numbered (1, 2, 3…) in visit order. Amber numbered markers. Tapping a pin shows a callout with the place name (reverse-geocoded from the pin's coordinate using `CLGeocoder` — lazy, cached per session). Map auto-fits to show the full route bounding box on load.
- **D-15:** Map height: fixed at 240pt in the detail panel. Stats row directly below.

### Photo Gallery
- **D-16:** Horizontal scrolling strip of square thumbnails (80×80pt) below the map. Uses `PHImageManager.requestImage` with `.fastFormat` for thumbnail loading on background thread. Main thread never blocks.
- **D-17:** Matching logic: `PHFetchOptions` filtered by `creationDate` within `[startDate, endDate]`. Secondary filter: GPS bounding box from routePoints (compute min/max lat/lon). Photos with nil location metadata (iCloud shared albums) are included via date-range-only fallback (DETAIL-04).
- **D-18:** Tapping a thumbnail opens a full-screen `UIViewController`-based photo viewer (can use a simple SwiftUI `.fullScreenCover` with `Image` + pinch-to-zoom). Out of scope for this phase — tap does nothing (add in a future phase if needed). Keep the thumbnail strip interactive-looking but disable the tap target.

### Claude's Discretion
- Exact pill visual design (corner radius, blur background, shadow)
- Elapsed timer formatting (whether to show seconds for short trips)
- Empty state for trip card list (if user has no trips yet)
- SwiftData → Firestore sync trigger timing after trip finalization
- Error state for photo permission denied
- Scroll-to-trip animation specifics in ProfileSheet
- Whether to show trip count on the drag strip handle

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 3 requirements
- `.planning/REQUIREMENTS.md` §Trip Logging (TRIP-01 through TRIP-07) — All trip logging requirements including manual start, auto-detect, 3-dismiss limit, active indicator, GPS capture, stop/name flow, route storage
- `.planning/REQUIREMENTS.md` §Profile Panel (PANEL-01 through PANEL-06) — Panel requirements: persistent handle, trip list order, trip card → detail navigation, "+" button, Profile button
- `.planning/REQUIREMENTS.md` §Trip Detail View (DETAIL-01 through DETAIL-05) — Route map requirements, stats, photo matching (date + GPS bounding box + date-only fallback), city name header

### Design system (established Phase 1)
- `Nomad/DesignSystem/AppColors.swift` — `Color.Nomad.*` namespace
- `Nomad/DesignSystem/AppFont.swift` — `AppFont.*` typography functions
- `Nomad/DesignSystem/PanelGradient.swift` — `.panelGradient()` modifier — MUST be applied to ProfileSheet and TripDetailSheet

### Existing UI stubs to replace
- `Nomad/Sheets/ProfileSheet.swift` — Current stub: hardcoded `GlobePinpoint.StubTrip`. Phase 3 replaces with real Firestore trips and adds route preview Path rendering.
- `Nomad/Sheets/TripDetailSheet.swift` — Current stub: hardcoded stats, no real map. Phase 3 adds real MapKit route map and photo gallery.
- `Nomad/Globe/GlobeView.swift` — Current stub: `hardcodedVisitedCodes`, `StubTrip` annotations. Phase 3 wires real Firestore data + adds recording pill + drag strip.

### Data pipeline (Phase 2 built)
- `Nomad/Location/LocationManager.swift` — `startRecording(tripId:)`, `stopRecording()`, `fetchUnsyncedPoints(tripId:)` — all ready to call from UI
- `Nomad/Location/VisitMonitor.swift` — Geofence exit + CLVisit monitoring. Note: 3-dismiss counter explicitly deferred to Phase 3 (see comment in file)
- `Nomad/Data/TripService.swift` — `finalizeTrip(...)` — writes trip doc + routePoints batch. Call after user names the trip.
- `Nomad/Data/FirestoreSchema.swift` — All Firestore path helpers: `tripDoc`, `routePointsCollection`, `userDoc`
- `Nomad/Auth/AuthManager.swift` — `currentUser.uid` — required for all Firestore reads

### Prior phase context
- `.planning/phases/02-data-auth-foundation/02-CONTEXT.md` — Full Firestore schema (D-12 through D-16), SwiftData RoutePoint model, TripService finalization decisions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Color.Nomad.*`, `AppFont.*`, `.panelGradient()` — Use everywhere, already established across all UI
- `LocationManager.startRecording(tripId:)` / `stopRecording()` — Ready to call; generates a UUID tripId at call site before passing in
- `TripService.finalizeTrip(...)` — Complete finalization pipeline; call with all required params after user names the trip
- `VisitMonitor.handleGeofenceExit()` — Already sends notification; Phase 3 adds dismiss counter before this call
- `FirestoreSchema` — All Firestore path helpers already defined; use these, do not hardcode paths
- `RouteSimplifier.coordinatesFromRoutePoints(_:)` — Converts `[RoutePoint]` to `[CLLocationCoordinate2D]` for MapKit use

### Established Patterns
- Stacked bottom sheets: TripDetailSheet is nested INSIDE ProfileSheet's body (INFRA-02) — do not move this
- `@Observable` pattern used by `GlobeViewModel`, `LocationManager`, `VisitMonitor` — new view models should follow same pattern
- `GlobeView` is the persistent backdrop; all overlays (drag strip, recording pill) are `ZStack` layers on top
- `MKMapView` via `UIViewRepresentable` is the established pattern (see `GlobeMapView`) — use same approach for TripDetailSheet map

### Integration Points
- `GlobeView` → add ZStack layers: drag strip (bottom), recording pill (top-center, conditional on `isRecording`)
- `GlobeViewModel` → replace stub data: fetch real trips from Firestore, use `visitedCountryCodes` from user doc for overlays
- `ProfileSheet` → replace `GlobePinpoint.StubTrip` with `TripDocument` model; add `scrollToTripId` param; draw route Path per card
- `TripDetailSheet` → replace stub stats with real Firestore trip data; add MapKit route map + photo strip
- `VisitMonitor` → add dismiss counter in `handleGeofenceExit()`, check `manualOnlyMode` flag before calling `sendTripStartNotification()`
- `NomadApp.swift` / app entry → inject `LocationManager` into environment (needs `ModelContext` from SwiftData container)

</code_context>

<specifics>
## Specific Ideas

- The drag strip at the bottom of the globe should feel like a natural extension of the globe surface — slim, unobtrusive, amber-tinted drag indicator
- Recording pill: "Recording — 1h 23m" with a pulsing red dot. Stop button in amber. Top-center positioning so it doesn't block the globe interaction area
- Trip card route preview: the SwiftUI Path should render on a dark background strip (like `Color.Nomad.globeBackground` at reduced height) — the amber route line against dark reads clearly and echoes the Strava aesthetic
- Numbered place pins: amber circle with white number inside — keep the amber language consistent with globe pinpoints

</specifics>

<deferred>
## Deferred Ideas

- Tapping a photo thumbnail to open a full-screen viewer — noted, intentionally skipped (D-18), can be a Phase 4 enhancement
- Settings to reset manual-only mode after 3 dismissals — out of scope
- Trip archiving or deletion from ProfileSheet — future phase

</deferred>

---

*Phase: 03-core-user-journey*
*Context gathered: 2026-04-06*
