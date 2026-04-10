# Codebase Concerns

**Analysis Date:** 2026-04-10

## Tech Debt

### Force Unwrapping in Critical Algorithms

**Area:** Route Simplification

- Issue: `RouteSimplifier.simplify()` uses forced unwrap on array access without guards
- Files: `Nomad/Location/RouteSimplifier.swift` (lines 20–21)
  ```swift
  let first = points.first!
  let last = points.last!
  ```
- Impact: Crashes if empty array passed (though guarded by count check at line 15, the guard check uses count only — if guard is ever removed during refactoring, crash is introduced)
- Fix approach: Replace with guard statements or guarantee non-empty precondition in documentation with explicit assertions

### Forced Unwrap in Bounding Box Calculation

**Area:** Location Clustering

- Issue: `CountryDetailSheet` force-unwraps min/max operations on coordinate arrays
- Files: `Nomad/Sheets/CountryDetailSheet.swift` (line 60)
  ```swift
  return (lats.min()!, lats.max()!, lons.min()!, lons.max()!)
  ```
- Impact: Crashes at runtime if arrays are empty (guarded by isEmpty checks at line 59, but fragile to refactoring)
- Fix approach: Return optional or guarantee non-empty input with precondition assertion

### Force Unwrap on Settings URL

**Area:** Photo Permission Handler

- Issue: Force unwrap of Settings URL string constant
- Files: `Nomad/Components/CityPhotoCarousel.swift` (line 80)
  ```swift
  Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
  ```
- Impact: Crash if URL constant changes (unlikely but possible in future iOS versions)
- Fix approach: Use guard or assert to handle URL creation failure

### Loose Error Handling with try?

**Area:** Firestore Operations

- Issue: Multiple Firestore reads silently fail with try? instead of logging or propagating errors
- Files:
  - `Nomad/Globe/GlobeViewModel.swift` (lines 71, 100, 104, 111)
  - `Nomad/Sheets/TripDetailSheet.swift` (line 71)
  - `Nomad/Location/LocationManager.swift` (lines 185, 200, 233)
  - `Nomad/Data/TripService.swift` (lines 155)
  - `Nomad/Data/PlaceCategoryService.swift` (line 55)
- Impact: User sees blank states or missing data without understanding why (no error logs, no retry prompts)
- Fix approach: Log errors with context (e.g., `print("[TripDetail] Route fetch failed: \(error)")`) and expose error states to UI with retry options

### Silent Failures in Geocoding

**Area:** Reverse Geocoding

- Issue: Reverse geocoding errors silently ignored; fallback behavior not documented
- Files:
  - `Nomad/Location/LocationManager.swift` (line 200)
  - `Nomad/Sheets/CountryDetailSheet.swift` (line 80)
  - `Nomad/Sheets/TripDetailSheet.swift` (implied in pause detection)
- Impact: Blank location names in Live Activity if geocoding fails; no user visibility
- Fix approach: Log failures, implement timeout/fallback to generic names, document behavior

## Known Bugs

### Live Activity Update Timer Race Condition

**Bug description:** Timer continues firing after recording stops if stopRecording() not called in correct sequence

- Symptoms: "Locating..." notifications appear after trip ends; memory leak from retained timer
- Files: `Nomad/Location/LocationManager.swift` (lines 66–73)
- Trigger: Call startRecording() multiple times without stopRecording() between them, or app backgrounded during recording without cleanup
- Workaround: Ensure stopRecording() is always called in GlobalView before starting new trip; deinit cleanup recommended

### Sheet Presentation State Not Cleared on Dismiss

**Bug description:** CountryDetailSheet or TripDetailSheet closing doesn't reset all internal state variables

- Symptoms: Rapid tap on country detail → previous sheet's photos/data visible; tabs scroll to wrong city; memory not released
- Files:
  - `Nomad/Sheets/CountryDetailSheet.swift` (lines 65–72, photo eviction)
  - `Nomad/Sheets/TripDetailSheet.swift` (lines 127–129, route loading)
- Trigger: Tap country detail, then immediately swipe down to dismiss before load completes
- Workaround: Wait for sheets to fully load before dismissing

### Pause Detection Double-Counting

**Bug description:** TripDetailSheet's pause detection algorithm may emit duplicate stops at cluster boundaries

- Symptoms: Route map shows two pins very close together for what should be one stop; inflated place count
- Files: `Nomad/Sheets/TripDetailSheet.swift` (lines 138–177)
- Trigger: User dwells at exact 90-second boundary; GPS jitter creates cluster boundary at stop point
- Workaround: None visible to user; map shows redundant pins

### Photo Gallery Incomplete on Limited Permissions

**Bug description:** PHPhotoLibrary.limited authorization state treated as authorized, but only subset of photos accessible

- Symptoms: Gallery shows fewer photos than expected; user sees "no photos" when they granted limited access
- Files:
  - `Nomad/Components/PhotoGalleryStrip.swift` (line 84)
  - `Nomad/Sheets/CountryDetailSheet.swift` (line 91)
- Trigger: User selects "Limited Photos" in iOS photo permission sheet
- Workaround: Implement explicit UI for limited access state; show count of available vs. total

## Security Considerations

### User ID Validation Insufficient

**Risk:** Auth bypass via user ID spoofing in Firestore reads

- Files:
  - `Nomad/Data/TripService.swift` (lines 98–122)
  - `Nomad/Globe/GlobeViewModel.swift` (lines 69, 100–119)
  - `Nomad/Sheets/TripDetailSheet.swift` (line 253)
- Current mitigation: Code comments say "T-03-01: userId must be Auth.auth().currentUser?.uid" but no runtime assertion
- Recommendations:
  1. Add inline assertion: `assert(userId == Auth.auth().currentUser?.uid, "User ID mismatch")`
  2. Move userId to dependency injection (not passed as parameter) to prevent caller error
  3. Firestore security rules MUST enforce: `request.auth.uid == resource.data.userId`

### Hardcoded Test Data in Production Code

**Risk:** Stub trip reveals internal structure; test credentials/routes leak to users

- Files:
  - `Nomad/Globe/GlobeViewModel.swift` (lines 121–133, injected testTrip)
  - `Nomad/Globe/GlobeViewModel.swift` (lines 139–150+, test Seattle route)
  - `Nomad/Location/VisitMonitor.swift` (implied manual testing mode at line 82)
- Current mitigation: None; test data unconditionally added to trips array
- Recommendations:
  1. Gate test data behind `#if DEBUG` conditional compilation
  2. Move test route to separate TestData.swift file imported only in DEBUG builds
  3. Add feature flag (e.g., `enableTestData: Bool = false`) if test data needed in production debugging

### Manual-Only Mode Override Persists

**Risk:** `UserDefaults` key "manualOnlyMode" allows trip recording bypass without location permission

- Files: `Nomad/Location/VisitMonitor.swift` (line 82)
- Current mitigation: Stored in UserDefaults (not encrypted)
- Recommendations:
  1. Document why this exists (legacy workaround?)
  2. If for testing, move to debug-only menu (not persisted)
  3. If for accessibility, add UI toggle in Settings + encryption

### GoogleService-Info.plist Not Committed

**Risk:** Firebase configuration missing from repo; users building from source get blank Google services

- Files: `Nomad/GoogleService-Info.plist` (present but likely in .gitignore)
- Current mitigation: Assumed to be added at build time
- Recommendations:
  1. Add placeholder file to repo with instructions for Firebase Console download
  2. Add build phase check: `if ! [ -f GoogleService-Info.plist ]; then exit 1; fi`

## Performance Bottlenecks

### Synchronous Photo Request with Opportunistic Delivery

**Slow operation:** Loading all matched photos in sequence with opportunistic delivery

- Files: `Nomad/Sheets/CountryDetailSheet.swift` (lines 125–147)
- Problem: `withCheckedContinuation` waits for each photo sequentially; network images block on degraded delivery
- Current behavior: Loads screenfuls of high-res city photos one-at-a-time
- Improvement path:
  1. Batch photo requests with `withTaskGroup` for 5–10 concurrent requests
  2. Implement progressive loading: show first 10 fast, lazy-load rest
  3. Limit target size for non-pinned clusters (smaller thumbnails faster)

### Route Simplification O(n²) in Worst Case

**Slow operation:** Ramer-Douglas-Peucker algorithm on large GPS traces

- Files: `Nomad/Location/RouteSimplifier.swift` (lines 14–37)
- Problem: Recursive subdivision can be O(n²) for long, complex routes; repeated array copying
- Current behavior: Simplifies full route trace (potentially 10,000+ points over multi-hour trip)
- Improvement path:
  1. Add early termination: if simplified array already < 500 points, stop recursing
  2. Pre-filter raw GPS points by timestamp before simplification (e.g., sample every 2s)
  3. Consider iterative (non-recursive) implementation to avoid stack depth issues

### Firestore Batch Writes on Main Thread

**Slow operation:** 400-point batches of route writes block main thread

- Files: `Nomad/Data/TripService.swift` (lines 64–83)
- Problem: `db.batch().commit()` is async but called in @MainActor context; UI may stall during large uploads
- Current behavior: Trip finalization writes 400pt batches sequentially after simplification
- Improvement path:
  1. Move batch write logic off @MainActor: `func syncRoutePoints(...) nonisolated async throws`
  2. Increase batch size to 500 (Firestore limit) to reduce commit calls
  3. Add progress callback for long uploads

### City Clustering Quadratic Distance Calculation

**Slow operation:** Proximity clustering compares all trip pairs

- Files: `Nomad/Sheets/CountryDetailSheet.swift` (implied in clusterTripsByProximity)
- Problem: Not shown in excerpt, but clustering trips by distance is likely O(n²)
- Improvement path:
  1. Switch to spatial hash or k-d tree for >50 trips per country
  2. Set max cluster distance to 25km (avoid ultra-distant trips clustering)

### Geocoding Throttle But No Debounce

**Slow operation:** Reverse geocoding called repeatedly for every visible cluster

- Files: `Nomad/Location/LocationManager.swift` (lines 38–39, throttle only)
- Problem: Throttle implemented (60s min), but no request dedup if multiple clusters request same area
- Current behavior: Each cluster load fires independent geocoder query
- Improvement path:
  1. Implement request cache keyed by rounded lat/lon (e.g., precision 0.1°)
  2. Share geocoding result across nearby clusters (within 5km)

## Fragile Areas

### Sheet Lifecycle Tightly Coupled to State

**Component/Module:** Sheet State Management

- Files:
  - `Nomad/Sheets/CountryDetailSheet.swift` (lines 39–50, load task)
  - `Nomad/Sheets/TripDetailSheet.swift` (lines 127–129, load task)
  - `Nomad/Globe/GlobeViewModel.swift` (lines 46–56, state mutation)
- Why fragile: `load()` called in `.task` modifier; if sheet dismissal doesn't cancel task, orphaned async work updates deallocated views
- Safe modification: Use `.onAppear { Task { await load() } }` for explicit lifecycle binding; call `task?.cancel()` in deinit or sheet dismissal handler
- Test coverage: No tests for sheet presentation/dismissal sequences; gaps in async cleanup

### Task.sleep() for Debounce/Retry Logic

**Component/Module:** Input Validation

- Files:
  - `Nomad/Onboarding/HomeCityScreen.swift` (line 223, 10s sleep)
  - `Nomad/Onboarding/HandleScreen.swift` (line 188, 500ms sleep)
  - `Nomad/Data/PlaceCategoryService.swift` (line 25, 200ms sleep)
  - `Nomad/Globe/GlobeView.swift` (lines 478, 514, 1.4s sleep)
- Why fragile: Hard-coded durations scattered across codebase; if duration needs to change, multiple files must update; sleep durations are not parameterized
- Safe modification: Extract sleep durations to Constants.swift; use DispatchQueue.main.asyncAfter with configurable delays; consider AsyncQueue pattern
- Test coverage: No way to test delays (tests would sleep); recommend using FakeClock for unit tests

### @weak self Closures Without Nil Checks

**Component/Module:** Event Handlers

- Files:
  - `Nomad/Location/LocationManager.swift` (line 69, Timer closure)
  - `Nomad/Sheets/CountryDetailSheet.swift` (line 45, task group)
  - `Nomad/Auth/AuthManager.swift` (line 38, Auth listener)
  - `Nomad/Components/TripRouteMapView.swift` (line 157, async dispatch)
- Why fragile: `[weak self]` capture without subsequent nil check; silent no-op if self dealloc'd mid-operation
- Safe modification: Always follow `[weak self]` with `guard let self = self else { return }` at closure start
- Test coverage: Hard to test deallocation patterns; recommend property-based tests of retain cycles

### Force Unwrap Chains in Array Subscripting

**Component/Module:** Array Utilities

- Files:
  - `Nomad/Sheets/CountryDetailSheet.swift` (lines 57–60, lat/lon extraction)
  - `Nomad/Sheets/TripDetailSheet.swift` (line 189–191, route preview fallback)
  - `Nomad/Components/PhotoGalleryStrip.swift` (line 132, safe subscript not always used)
- Why fragile: Nested array unpacking relies on index bounds guaranteed by outer logic; refactoring one loop can break another
- Safe modification: Use safe subscript extension (line 158 in CountryDetailSheet shows pattern); apply consistently
- Test coverage: No test data for edge cases (empty arrays, mismatched nested structure)

### Pause Detection Hardcoded Constants

**Component/Module:** Stop Point Detection

- Files: `Nomad/Sheets/TripDetailSheet.swift` (lines 138–141, 40m radius, 90s min)
- Why fragile: Algorithm parameters hardcoded; no configuration path; if UX wants "detect stops at 60m instead", code must change
- Safe modification: Move to Trip constants or @State property with UI setter; document why 40m/90s chosen
- Test coverage: No unit tests for detectPauseStops(); only manual trip testing

## Scaling Limits

### Firestore Reads Unbounded for Large Trip Counts

**Current capacity:** ~100 trips per user loads in <500ms

**Limit:** User with 500+ trips causes fetchTrips() to download all documents; pagination not implemented

- Files: `Nomad/Data/TripService.swift` (lines 98–102)
- Scaling path:
  1. Implement cursor-based pagination: `query.startAfter(lastDocSnapshot).limit(50).getDocuments()`
  2. Cache last cursor in @State; load next batch on scroll
  3. Add estimated trip count fetch (single aggregation query) for UX feedback

### PhotoGalleryStrip Loads All Matched Photos into Memory

**Current capacity:** ~50 trip photos at 3MB each = 150MB memory

**Limit:** 1000+ photos from month-long international trip would hit memory cap; crashes on iPhone 12 mini

- Files: `Nomad/Sheets/CountryDetailSheet.swift` (lines 121–147)
- Scaling path:
  1. Implement LazyVStack with on-demand image loading (not loadAll into array)
  2. LRU cache: keep only 20 images in memory, release when scrolled out
  3. Downsample images to screen resolution (3x target size, not full library resolution)

### Route Point Batch Size Assumes Small Trips

**Current capacity:** 400 points per batch; 2-hour trip ~500 points, 10-hour trip ~2500 points

**Limit:** 100-point trips batch well; 24-hour road trips with 10,000+ points cause many round-trips and potential timeouts

- Files: `Nomad/Data/TripService.swift` (lines 64–83)
- Scaling path:
  1. Adaptive batch sizing: if pointCount > 5000, use 500-point batches; if < 500, use single batch
  2. Parallel batch writes: use taskGroup to commit 3 batches concurrently (stays under quota)
  3. Server-side aggregation: consider batch endpoint that accepts 10,000-point payload

### Core Location Visits API Not Scalable for Frequent Stops

**Current capacity:** ~20 visits per day (dwell-based)

**Limit:** Urban explorer with visit every 5min (12/hour) exceeds notification budget; VisitMonitor fires 288 notifications/day

- Files: `Nomad/Location/VisitMonitor.swift` (lines 60–108)
- Scaling path:
  1. Batch visit notifications: coalesce 5 visits, fire one "5 stops detected" notification
  2. Implement visit aggregation: store raw visits locally, send batch upload to Firestore every 1 hour
  3. Add user setting: "Notify every visit" vs. "Notify every 10 minutes" vs. "Batch daily"

## Dependencies at Risk

### Firebase Auth Tightly Coupled

**Risk:** Firebase Auth.auth().currentUser?uid used in 6+ places without abstraction

- Files:
  - `Nomad/Globe/GlobeViewModel.swift` (line 69, 95)
  - `Nomad/Sheets/TripDetailSheet.swift` (line 253)
  - `Nomad/Auth/AuthManager.swift` (line 38)
  - `Nomad/Data/TripService.swift` (line 97)
- Impact: If Firebase Auth deprecated or replaced (e.g., migrate to Supabase), 10+ call sites must update
- Migration plan:
  1. Create UserIDProvider protocol: `protocol UserIDProvider { var currentUserID: String? { get } }`
  2. Implement FirebaseUserIDProvider; inject as @Environment
  3. All callsites use `@Environment(UserIDProvider.self).currentUserID` instead of direct Firebase calls

### MapKit/CLLocationManager Hard Dependency

**Risk:** MapKit used for reverse geocoding and routing; no abstraction layer

- Files:
  - `Nomad/Location/LocationManager.swift` (CLLocationUpdate.liveUpdates)
  - `Nomad/Sheets/CountryDetailSheet.swift` (CLGeocoder)
  - `Nomad/Components/TripRouteMapView.swift` (MKMapView)
- Impact: Cannot swap for Google Maps or add offline maps support without major refactor
- Migration plan:
  1. Create GeocodingProvider protocol; implement CLGeocoderProvider, mock for tests
  2. Move CLLocationManager lifecycle to LocationProvider protocol
  3. Wrap MKMapView in custom map view controller; support future swap

### Photos Framework Authorization Scattered

**Risk:** PHPhotoLibrary checks in 3+ places with inconsistent fallback logic

- Files:
  - `Nomad/Sheets/CountryDetailSheet.swift` (line 90)
  - `Nomad/Components/PhotoGalleryStrip.swift` (line 76)
  - `Nomad/Components/TripRouteMapView.swift` (implied from errors)
- Impact: Changes to limited access handling must propagate to all files; easy to miss one
- Migration plan:
  1. Create PhotoAuthorizationProvider service
  2. Centralize request/status check logic
  3. Return enum: `.authorized`, `.limited(count)`, `.denied`, `.notDetermined`

## Missing Critical Features

### No Trip Editing After Finalization

**Problem:** Once user names a trip, cannot edit city name, dates, or delete trip

**Blocks:** User corrects wrong city name; user deletes accidental/test trip; user re-categorizes activity

**Workaround:** None; user stuck with wrong metadata

### No Offline Trip Recording

**Problem:** GPS recording requires active Firestore connection for user validation at start

**Blocks:** User starts trip in area with poor connectivity; trip not recorded until connection returns

**Workaround:** User must wait for network before starting

### No Rich Text or Photos in Trip Notes

**Problem:** Trips support only city name + auto-detected places; no user journal entries, photo captions, or rich metadata

**Blocks:** User cannot document why they visited a place; cannot add personal context to trip

**Workaround:** Use separate Notes app; metadata lost

### No Trip Sharing

**Problem:** No way to share a trip (route, photos, stats) with friends or social media

**Blocks:** Social feature entirely missing; no viral loop

**Workaround:** Manual screenshot/description

### No Analytics

**Problem:** No event tracking (trip created, user signed up, country viewed, etc.)

**Blocks:** Cannot measure engagement; cannot identify churn; cannot A/B test features

**Workaround:** None; pure guessing on what drives retention

## Test Coverage Gaps

### No Unit Tests for Route Simplification

**What's not tested:** Ramer-Douglas-Peucker algorithm edge cases (collinear points, sharp turns, single-point input)

**Files:** `Nomad/Location/RouteSimplifier.swift`

**Risk:** Refactoring or optimization could introduce route-corruption bugs undetected for weeks (only surface during production trip finalization)

**Priority:** High — algorithm is deterministic and testable in isolation

### No Tests for Pause Detection Logic

**What's not tested:** Stop cluster detection at various GPS accuracy levels; boundary conditions (exactly 90s, 40m radius)

**Files:** `Nomad/Sheets/TripDetailSheet.swift` (lines 138–177)

**Risk:** Algorithm may double-count, miss stops, or produce wrong centroids; only found via manual testing or user reports

**Priority:** High — core feature of trip detail

### No Tests for Photo Matching Logic

**What's not tested:** Photo location matching with nil-location fallback; boundary box calculations; date-range filtering

**Files:**
- `Nomad/Sheets/CountryDetailSheet.swift` (lines 104–147)
- `Nomad/Components/PhotoGalleryStrip.swift` (lines 90–110)

**Risk:** Photos missing or wrong photos shown for trips; user confusion on why gallery empty when photos exist

**Priority:** Medium — impacts UX but not critical path

### No Integration Tests for Sheet Lifecycle

**What's not tested:** Sheet presentation, async loading, dismissal without cancellation bugs; state resets between presentations

**Files:**
- `Nomad/Sheets/CountryDetailSheet.swift`
- `Nomad/Sheets/TripDetailSheet.swift`

**Risk:** Sheet crashes on rapid open/close; orphaned tasks update deallocated views; memory leaks

**Priority:** Medium — affects stability but not always caught

### No Tests for Firestore Schema Compatibility

**What's not tested:** TripDocument decoding from Firestore; schema migration if fields added/removed; null handling

**Files:** `Nomad/Data/Models/TripDocument.swift` (not shown but exists)

**Risk:** Silent data loss if schema mismatch; user trips appear blank or app crashes on fetch

**Priority:** High — data integrity

### No Concurrency/Race Condition Tests

**What's not tested:** Multiple trips started in quick succession; rapid sheet open/close; location updates during app backgrounding

**Files:** Multiple (Location, ViewModel, Sheet lifecycle)

**Risk:** Race conditions in @Observable state updates; use-after-free if task cancellation timing wrong

**Priority:** High — hardest bugs to find in production

---

*Concerns audit: 2026-04-10*
