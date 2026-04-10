# Coding Conventions

**Analysis Date:** 2026-04-10

## Naming Patterns

**Files:**
- SwiftUI views: `[Name]View.swift` or `[Name]Screen.swift` (e.g., `GlobeView.swift`, `SignUpScreen.swift`)
- ViewModels: `[Name]ViewModel.swift` (e.g., `GlobeViewModel.swift`, `CountryDetailViewModel.swift`)
- Services: `[Name]Service.swift` (e.g., `UserService.swift`, `TripService.swift`, `AuthManager.swift`)
- Models: `[Name].swift` (e.g., `TripDocument.swift`, `CountryFeature.swift`, `RoutePoint.swift`)
- Utilities: `[Name].swift` as enums (e.g., `RouteSimplifier.swift`, `GeoJSONParser.swift`)
- Design system: `[ComponentName].swift` (e.g., `AppColors.swift`, `AppFont.swift`, `PanelGradient.swift`)
- Delegates/Observers: `[Name]Monitor.swift` or `[Name]Manager.swift` (e.g., `VisitMonitor.swift`, `LocationManager.swift`)

**Functions:**
- CamelCase starting with lowercase verb: `startMonitoring()`, `loadGlobeData()`, `fetchUserDocument()`, `handleGeofenceExit()`
- Boolean getters use positive language: `isRecording`, `isLoading`, `isMonitoring` (not `notLoading`)
- Private helpers prefixed with underscore in computed properties: `_authManager`, `_userService`
- Async functions explicitly mark returning type: `async throws -> [CountryFeature]`

**Variables:**
- Properties: camelCase: `homeCityName`, `routeCoordinates`, `isLoading`, `errorMessage`
- State properties: `@State private var fieldName: Type`
- Environment properties: `@Environment(Manager.self) private var manager`
- Accumulated properties: descriptive names like `accumulatedDistanceMeters`, `recordingStartDate`

**Types:**
- View structs: `struct NameView: View { ... }`
- Classes: `final class Name` (always `final` for class types to prevent inheritance; see `GlobeViewModel`, `UserService`, `AuthManager`)
- Models: Immutable structs with `Identifiable` or simple `struct` (e.g., `struct TripDocument: Identifiable`, `struct CountryFeature: Identifiable`)
- SwiftData models: `@Model final class Name` (e.g., `RoutePoint`, `TripLocal`)
- Enums for errors: `enum NameError: Error` or `enum NameError: LocalizedError` (e.g., `GlobeError`, `GoogleSignInError`)
- Enums for state/categories: `enum AuthState { case loading, unauthenticated, authenticated(User) }`

## Code Style

**Formatting:**
- No explicit formatter configured (no .swiftformat or swiftlint.yml detected)
- Indentation: 4 spaces (inferred from code samples)
- Line length: Not strictly enforced; typical lines ~80-100 chars
- Brace style: Opening brace on same line (K&R style): `func name() { ... }`

**Linting:**
- No SwiftLint configuration present
- Code follows Swift style guide conventions

## Import Organization

**Order:**
1. System frameworks (Swift std lib or Apple frameworks): `import SwiftUI`, `import Foundation`, `import CoreLocation`
2. Third-party frameworks with `@preconcurrency`: `@preconcurrency import FirebaseAuth`, `@preconcurrency import FirebaseFirestore`, `@preconcurrency import MapKit`
3. Internal/local imports: None used (single-target app)

**Path Aliases:**
- Not applicable for Swift projects (uses default module imports)

## Error Handling

**Patterns:**
- Explicit error types: Define `enum NameError: Error` or `LocalizedError` at file scope
  ```swift
  enum GlobeError: Error {
      case fileNotFound
      case parseError(String)
  }
  ```
- Throwing functions: Mark with `async throws -> ReturnType`
  ```swift
  func createUserWithHandle(uid: String, handle: String, email: String) async throws { ... }
  ```
- Try-catch blocks: Used for async operations, error logged via `print()` or silently caught
  ```swift
  do {
      let doc = try await db.collection("users").document(uid).getDocument()
  } catch {
      // Silently fail or print error — no centralized error handler
  }
  ```
- Fail-safe defaults: Return false/empty on network errors to avoid propagating failures
  ```swift
  func isHandleAvailable(_ handle: String) async -> Bool {
      do {
          let doc = try await db.collection("usernames").document(handle.lowercased()).getDocument()
          return !doc.exists
      } catch {
          return false  // Fail safe: assume unavailable on error
      }
  }
  ```

## Logging

**Framework:** `print()` with bracketed module prefix

**Patterns:**
- Prefix: `print("[Module] message")` where Module is the feature area
- Examples:
  ```swift
  print("[Globe] Loaded \(loaded.count) countries")
  print("[Globe] ERROR: \(error)")
  print("[TripDetail] Route fetch error: \(error)")
  ```
- Uses: Data load completion, error state changes, milestone events
- No log levels (no warn, error, debug levels) — only stdout print

## Comments

**When to Comment:**
- File-level docstring: Always (see below)
- Algorithm explanation: When logic is non-obvious (e.g., route simplification, geofence detection)
- Data flow notes: At major state transitions
- External references: When referencing design docs (e.g., "D-09: AuthManager and UserService injected as environment objects")

**File Header Pattern:**
```swift
// FileName — One-sentence purpose.
// Context: What it does and why.
// D-XX: Reference to design doc / decision
// T-XX: Technical constraint / requirement
```

Example from `NomadApp.swift`:
```swift
// NomadApp — root entry point.
// Auth-gated routing: loading -> silent wait, unauthenticated -> onboarding, authenticated -> globe.
// D-09: AuthManager and UserService injected as environment objects for all descendant views.
```

**JSDoc/TSDoc:**
- Swift has no TSDoc, but docstring comments use `///` format for public functions
- Not consistently used; only method-level comments when complex logic exists
- Format example (from `RouteSimplifier.swift`):
  ```swift
  /// Simplify a GPS trace using the Ramer-Douglas-Peucker algorithm.
  /// - Parameters:
  ///   - points: Raw GPS coordinates in recording order.
  ///   - epsilon: Distance tolerance in meters.
  /// - Returns: Simplified coordinate array preserving route shape.
  static func simplify(_ points: [CLLocationCoordinate2D], epsilon: Double) -> [CLLocationCoordinate2D]
  ```

## Function Design

**Size:** Small functions (typically 10-40 lines); larger functions broken into private helpers with MARK sections

**Parameters:**
- Explicit type annotations always
- Keyword arguments for clarity: `startMonitoring(homeCityLatitude: Double, homeCityLongitude: Double, radius: Double = 50_000)`
- Default parameters used for optional behavior (e.g., `radius` parameter above with default 50km)

**Return Values:**
- Explicit return type annotation: `-> [CountryFeature]`, `-> Bool`, `-> String?`
- Async functions: `async -> Type` or `async throws -> Type`
- Computed properties prefer short, derived values over side effects

## Module Design

**Exports:**
- No explicit `public`/`private` module-level exports (single-target app)
- Files use `private` liberally within file (private methods, private helpers)
- Services and ViewModels exposed at app level via `@Environment`

**Barrel Files:**
- Not used (no index.ts or __init__.swift files creating aggregated exports)
- Each service/view defined in its own file

## Section Organization with MARK

**Pattern:** Use `// MARK: - SectionName` to organize code within files

**Typical order (example from `GlobeViewModel.swift`):**
1. File comment (purpose/context)
2. `@Observable @MainActor class Name`
3. Properties section: `// MARK: - Properties` or implicit at top
4. Computed properties
5. Main public methods: `// MARK: - Public Methods` or named for feature (e.g., `// MARK: - Country Detail Sheet`)
6. Private methods: `// MARK: - Private` or feature-specific sections
7. Test data or helpers: `// MARK: - Test Route Data`

Example layout from `TripDetailSheet.swift`:
```swift
// MARK: - TripDetailSheet
struct TripDetailSheet: View { ... }

// MARK: - Pause Detection
private func detectPauseStops(...) { ... }

// MARK: - Open in Apple Maps
private func openInMaps() { ... }

// MARK: - Stats Row
private var statsRow: some View { ... }
```

## SwiftUI View Structure

**Property Declaration Order:**
1. Environment properties: `@Environment`, `@EnvironmentObject`
2. State properties: `@State private var`
3. Parameters passed in: `var coordinator: OnboardingCoordinator`

**Body Composition:**
- Use `@ViewBuilder` for complex conditional views
- Extract sub-views as computed properties: `private var emailField: some View`
- Use `// MARK: - SectionName` to delineate major sections within body

**Design System:**
- Colors accessed via `Color.Nomad.textPrimary`, `Color.Nomad.panelBlack`, etc.
- Fonts accessed via `AppFont.title()`, `AppFont.body()`, `AppFont.caption()`, `AppFont.buttonLabel()`
- No magic numbers for spacing; constants defined in design system or inline with comments

## Isolation & Concurrency

**MainActor:**
- All UI-updating classes marked with `@MainActor`: `@MainActor final class GlobeViewModel`, `@MainActor final class UserService`
- Prevents concurrent access to UI state
- ViewController/NSObject subclasses: nonisolated delegate methods crossing into `@MainActor` via `Task { @MainActor in ... }`

**Preconcurrency:**
- Firebase imports use `@preconcurrency`: `@preconcurrency import FirebaseAuth` to suppress concurrency warnings from non-Sendable types
- Allows async/await code without full type annotation overhead

## Preview & Debug Code

**Pattern:**
```swift
#if DEBUG
#Preview {
    ViewName()
        .environment(...)
}
#endif
```

**Usage:**
- Wrapped in `#if DEBUG` blocks
- Located at end of file
- Multiple previews allowed: `#Preview("Label") { ... }`
- Examples: `FontValidationView` in `AppFont.swift`, preview stubs in all sheet views

---

*Convention analysis: 2026-04-10*
