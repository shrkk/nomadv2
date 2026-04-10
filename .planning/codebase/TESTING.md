# Testing Patterns

**Analysis Date:** 2026-04-10

## Test Framework

**Status:** Not detected

No test files, test targets, or test frameworks (XCTest, Quick, Nimble) found in the codebase.

- XCTest: Not configured
- Test target: No `.xctest` build phase or `Tests/` directory
- Test runner: No test automation configured in CI/CD

## Testing Approach (Current)

**Manual SwiftUI Previews:**
- All views have `#Preview` blocks wrapped in `#if DEBUG` for manual canvas testing
- Examples: `AppFont.swift`, `PanelGradient.swift`, `TripDetailSheet.swift`, `ProfileSheet.swift`
- Pattern: Views are tested by rendering in Xcode preview canvas

**Hardcoded Test Data:**
- Test data embedded in view models and live code:
  - `GlobeViewModel.testSeattleRoute`: Static hardcoded route for Seattle walk trip visualization (lines 143-189 in `GlobeViewModel.swift`)
  - Test trip injected live: `GlobeViewModel.swift` lines 121-133 inject a test Seattle trip into the trips array
  - Flag: `if trip.id == "test-seattle-walk"` guards test-specific behavior in `loadRouteOverlay()`
- Not isolated: Test data persists in production code

**Manual Testing Entry Points:**
- `GlobeViewModel.loadGlobeData()`: Loads real Firestore data + injects test Seattle trip
- `TripDetailSheet.fetchRoutePoints()`: Fetches route from Firestore or Stubs on network errors
- No abstraction layer between test and production paths

## Mocking Strategy

**Not Implemented:**
- No mocking framework (Mockable, Mock, etc.)
- No protocol-based abstraction for dependencies
- Direct dependency instantiation: `let tripService = TripService()` inside functions

**Service Instantiation Pattern (from `GlobeViewModel.swift`):**
```swift
func loadGlobeData() async {
    let parser = GeoJSONParser()
    let loaded = try await parser.loadCountries()
    // ...
    let tripService = TripService()
    if let fetched = try? await tripService.fetchTrips(userId: uid) { ... }
    let userService = UserService()
    if let userData = try? await userService.fetchUserDocument(uid: uid) { ... }
}
```

**What's Not Mocked:**
- Firestore database (real DB accessed, no test/staging database switch)
- Firebase Auth (real Auth.auth() used)
- Location services (real CLLocationManager used)
- Photo library (real PHPhotoLibrary used)

## Test Data & Fixtures

**Hardcoded Data:**
- Test route: `GlobeViewModel.testSeattleRoute` — 30-point GPS walk from The Standard Apartments to Gates Foundation, Seattle
  ```swift
  static let testSeattleRoute: [CLLocationCoordinate2D] = [
      CLLocationCoordinate2D(latitude: 47.6145, longitude: -122.3275),
      // ... 28 more points
  ]
  ```
- Test trip object:
  ```swift
  let testTrip = TripDocument(
      id: "test-seattle-walk",
      cityName: "Seattle",
      startDate: Date(timeIntervalSinceNow: -86400 * 3),
      endDate: Date(timeIntervalSinceNow: -86400 * 3 + 5400),
      stepCount: 4200,
      distanceMeters: 3100,
      routePreview: [[47.6145, -122.3424], [47.6386, -122.3372]],
      visitedCountryCodes: ["US"],
      placeCounts: ["culture": 1]
  )
  trips.append(testTrip)
  ```

**Location:** `Nomad/Globe/GlobeViewModel.swift` (lines 121-189)

**Accessibility:**
- Memberwise initializers provided for models to enable test construction:
  ```swift
  init(
      id: String,
      cityName: String,
      startDate: Date,
      endDate: Date,
      // ... more parameters
  ) { self.id = id; ... }
  ```
  (e.g., `TripDocument`, `RoutePoint`, `TripLocal`)

## Preview-Based Testing

**View Previews:**

- `AppFont.swift` (lines 26-47):
  ```swift
  #if DEBUG
  struct FontValidationView: View {
      var body: some View {
          VStack(spacing: 16) {
              Text("Title 28pt Inter SemiBold").font(AppFont.title())
              Text("Subheading 20pt Inter SemiBold").font(AppFont.subheading())
              // ... more sizes
          }
      }
  }
  #Preview {
      FontValidationView()
  }
  #endif
  ```

- `TripDetailSheet.swift` (lines 366-390):
  ```swift
  #if DEBUG
  #Preview {
      TripDetailSheet(trip: TripDocument(...))
          .environment(\.modelContext, ModelContext(...))
  }
  #endif
  ```

- `ProfileSheet.swift` (lines 297-360): Multiple previews:
  ```swift
  #Preview("With trips") { ... }
  #Preview("Empty state") { ... }
  ```

**Limitations:**
- Previews don't execute async code (no Firestore fetch in preview)
- Rely on memberwise init with mock data
- No automated assertion/validation in previews
- Require manual visual inspection

## Async Testing

**Pattern:** No explicit async test framework; async tested implicitly through `Task { ... }`

Example from `AuthManager.syncOnboardingStatus()`:
```swift
private func syncOnboardingStatus(uid: String) async {
    if UserDefaults.standard.bool(forKey: "onboardingComplete") {
        onboardingComplete = true
        return
    }
    do {
        let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
        let complete = doc.data()?["onboardingComplete"] as? Bool ?? false
        onboardingComplete = complete
    } catch {
        // Network failure — leave onboardingComplete as false
    }
}
```

**Testing Approach:** Called from `loadAuthState()` triggered by view lifecycle; no test harness.

## Error Testing

**No Formal Error Tests:** Errors tested implicitly through:

1. **Fail-safe defaults:** Functions return false/empty on error:
   ```swift
   func isHandleAvailable(_ handle: String) async -> Bool {
       do { ... } catch { return false }  // Fail safe
   }
   ```

2. **Error state in UI:** Errors set as published properties and shown in UI:
   ```swift
   @State private var routeFetchError = false

   private func fetchRoutePoints() async {
       do {
           // ...
       } catch {
           routeFetchError = true
       }
   }
   ```

3. **Manual inspection:** Developer manually triggers network failures and observes state changes.

## Coverage

**Requirements:** None enforced

**Current Coverage:** Unknown; no coverage tooling configured

**Untested Areas (High Risk):**
- `GlobeViewModel`: Firestore fetch, photo loading, route overlay logic
- `AuthManager`: Google Sign-In flow, auth state changes, listener cleanup
- `LocationManager`: Background GPS, Live Activity updates, geofence detection
- `TripService`: Batch uploads, trip filtering, data transformation
- `UserService`: Handle uniqueness checks, atomic batch writes, user document updates

## Test Types

**Unit Tests:**
- Not implemented
- Would test: Models (TripDocument, RoutePoint), utilities (RouteSimplifier, GeoJSONParser), business logic (error handling)

**Integration Tests:**
- Not implemented
- Would test: Firestore read/write workflows, Auth state transitions, full trip lifecycle

**E2E Tests:**
- Not implemented
- Would test: Full onboarding flow, trip creation/logging, profile viewing

**Preview-based Testing (Manual):**
- Implemented but not automated
- Tests: View layout, color scheme, font sizes, state-driven UI changes

## Backend Testing (Firebase Functions)

**Test Framework:** Not configured

Backend code: `functions/src/index.ts` (onUserDeleted trigger)

No test framework, no mocks, no test cases for:
- User deletion cascade (users/{uid} + usernames/{handle} cleanup)
- Batch write atomicity
- Error handling when user doc missing or handle undefined

**Manual Testing:** Via Firebase Console triggers or local emulator (not evidenced in codebase)

## Recommended Testing Gaps to Address

**High Priority:**
1. Unit tests for models and utilities (Route simplification, GeoJSON parsing)
2. Mocking layer for Firestore/Auth to enable offline testing
3. View state tests (UI behavior on data changes)
4. Error recovery tests (network failures, auth state transitions)

**Medium Priority:**
5. Snapshot tests for critical views (profile, trip detail)
6. Integration tests for onboarding flow
7. Firebase function tests (user deletion cleanup)

**Low Priority:**
8. E2E tests (device-based or Simulator automation)
9. Performance tests (route simplification, large dataset loading)

---

*Testing analysis: 2026-04-10*
