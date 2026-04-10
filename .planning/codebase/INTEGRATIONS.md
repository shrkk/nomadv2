# External Integrations

**Analysis Date:** 2026-04-10

## APIs & External Services

**Google OAuth 2.0:**
- Service: Google Sign-In (user authentication)
  - SDK/Client: `GoogleSignIn` framework (iOS), `GoogleSignInSwift` framework
  - Auth: `GoogleService-Info.plist` contains CLIENT_ID (`601995922194-vppjto4lb0j8h33iqis5amr0qeur47he.apps.googleusercontent.com`)
  - Flow: OAuth2 token → Firebase Auth credential conversion
  - Implementation: `AuthManager.signInWithGoogle()` in `/Users/rahulb/nomadv2/nomadv2/Nomad/Auth/AuthManager.swift`
  - Scope: Read user email and profile for account creation

**MapKit POI Service:**
- Service: Apple's Map Points of Interest (place categorization)
  - SDK/Client: `MapKit.MKLocalPointsOfInterestRequest`, `MKLocalSearch`
  - No API key required (built into iOS system services)
  - Implementation: `PlaceCategoryService.categorize()` in `/Users/rahulb/nomadv2/nomadv2/Nomad/Data/PlaceCategoryService.swift`
  - Purpose: Categorize stops by POI type (restaurant, museum, park, etc.) into 6 scoring dimensions (Food, Culture, Nature, Nightlife, Wellness, Local)
  - Rate limiting: 200ms delay between sequential calls (PLACE-02, T-02-14)
  - Caching: 2-decimal coordinate grid (~1.1km cells) to reduce repeated queries

**Apple HealthKit:**
- Service: HealthKit framework (step count)
  - SDK/Client: `HealthKit` framework
  - No external API (local device data only)
  - Permission: `NSHealthShareUsageDescription` in Info.plist
  - Purpose: Read step count for trip stat summaries
  - Files: `/Users/rahulb/nomadv2/nomadv2/Nomad/Onboarding/HealthPermissionScreen.swift`

**Apple Photos Framework:**
- Service: Photo Library access
  - SDK/Client: `Photos` framework
  - No external API (local device data only)
  - Permission: `NSPhotoLibraryUsageDescription` in Info.plist
  - Purpose: Match photos from device library to trips by date and location
  - Files: `/Users/rahulb/nomadv2/nomadv2/Nomad/Components/CityPhotoCarousel.swift`, `/Users/rahulb/nomadv2/nomadv2/Nomad/Components/PhotoGalleryStrip.swift`

## Data Storage

**Databases:**
- Firestore (Cloud Firestore)
  - Project: `nomad-d92cb`
  - Collections:
    - `users/{uid}` - User profile documents (handle, email, home city, onboarding status)
    - `users/{uid}/trips/{tripId}` - Trip metadata (dates, cities, route preview, place counts, country codes, stats)
    - `users/{uid}/trips/{tripId}/routePoints` - GPS point subcollection (latitude, longitude, timestamp, accuracy, altitude)
    - `usernames/{handle}` - Username reservation index for uniqueness checking (D-04, D-12)
  - Connection: Embedded in Firebase SDK, authenticated via Firebase Auth
  - Client: `FirebaseFirestore` framework (imported as `@preconcurrency import FirebaseFirestore`)
  - Schema: Defined in `/Users/rahulb/nomadv2/nomadv2/Nomad/Data/FirestoreSchema.swift`
  - Batch writes: RoutePoints synced in batches of 400 ops to stay under 500-operation Firestore limit (D-13)

**Local Storage:**
- SwiftData
  - Models: `RoutePoint`, `TripLocal` in `/Users/rahulb/nomadv2/nomadv2/Nomad/Data/Models/`
  - Purpose: Buffer GPS points locally before Firestore sync, store active trip metadata
  - Tracks sync status via `isSynced` flag on each model
- UserDefaults
  - Key `onboardingComplete` - Cached onboarding status (fast-path check, synced with Firestore on auth state change)
  - Used by `AuthManager` and `VisitMonitor`

**File Storage:**
- Local filesystem only - No cloud file storage integration detected
- Device Photo Library (via Photos framework)

**Caching:**
- In-memory POI cache: `PlaceCategoryService` caches coordinate → place counts by 2-decimal grid key

## Authentication & Identity

**Auth Provider:**
- Firebase Authentication
  - Email/password auth via `Auth.auth().createUser(withEmail:password:)` and `Auth.auth().signIn(withEmail:password:)`
  - Google OAuth2 via `GoogleSignIn.sharedInstance.signIn()` → Firebase credential conversion
  - Auth state listener: `Auth.auth().addStateDidChangeListener()` in `AuthManager` drives root view routing
  - Implementation: `/Users/rahulb/nomadv2/nomadv2/Nomad/Auth/AuthManager.swift`

**User Profile Management:**
- Firebase user document (`users/{uid}`)
  - Fields: handle (username), email, homeCityName, homeCityLatitude, homeCityLongitude, discoveryScope, geofenceRadius, createdAt, onboardingComplete
  - Managed by `UserService` in `/Users/rahulb/nomadv2/nomadv2/Nomad/Auth/UserService.swift`

**Atomic Operations:**
- Username reservation: `UserService.createUserWithHandle()` uses Firestore batch to atomically write `users/{uid}` and `usernames/{handle}` (D-12)

## Monitoring & Observability

**Error Tracking:**
- Not detected - No external error tracking service (Sentry, Bugsnag, etc.)

**Logs:**
- Firebase Cloud Functions: console.log() in TypeScript functions
  - Example: User deletion logs in `/Users/rahulb/nomadv2/nomadv2/functions/src/index.ts`
- iOS: No centralized logging framework detected, likely uses standard OSLog or print()

**Analytics:**
- Firebase Analytics: Disabled in GoogleService-Info.plist (`IS_ANALYTICS_ENABLED = false`)
- No third-party analytics service detected

## CI/CD & Deployment

**Hosting:**
- iOS App: Apple App Store (requires code signing, provisioning profiles)
- Backend: Firebase Cloud (Google-managed)
  - Cloud Functions: auto-deployed via `firebase deploy --only functions`
  - Firestore: managed database, rules in `firestore.rules`

**CI Pipeline:**
- Not detected - No CI/CD configuration files (GitHub Actions, GitLab CI, etc.)
- Manual deployment: `firebase deploy` runs locally (functions/package.json has deploy script)

**Deployment Configuration:**
- `.firebaserc` specifies Firebase project: `nomad-d92cb`
- `firebase.json` configures functions runtime (nodejs20) and Firestore rules location

## Environment Configuration

**Required env vars:**
- None detected in source code (GoogleService-Info.plist is embedded in bundle)
- Firebase project variables are compile-time configuration (not runtime env vars)

**Secrets location:**
- GoogleService-Info.plist embedded in `Nomad` target (generated by Firebase Console)
- Google OAuth CLIENT_ID in GoogleService-Info.plist
- Firebase configuration: `.firebaserc` and `firebase.json` in root

**Note:** No `.env` files detected. Configuration is managed via Firebase Console and Xcode project settings.

## Webhooks & Callbacks

**Incoming:**
- None detected - App does not expose public HTTP endpoints

**Outgoing:**
- Firebase Authentication user deletion hook
  - Trigger: User deleted via Firebase Console or Admin SDK
  - Function: `onUserDeleted()` in `/Users/rahulb/nomadv2/nomadv2/functions/src/index.ts`
  - Action: Cleans up `users/{uid}` document and `usernames/{handle}` reservation
  - No external webhooks to third parties

**Server-to-Client Messaging:**
- UserNotifications framework for geofence/trip prompt alerts (local, not cloud messaging)
- ActivityKit for live activity updates during trip recording
- Firestore real-time listeners (if implemented) for trip updates

## Real-Time Listeners (Potential)

**Not explicitly detected in explored files, but Firestore pattern suggests:**
- May use `addSnapshotListener()` on trip documents or route points during active recording
- Live Activity updates via `ActivityKit.update()` calls to system framework

## Third-Party Libraries

**No external REST client libraries detected** - Uses native URLSession implicitly via Firebase SDKs

**No ORM detected** - Direct Firestore SDK usage with manual document encoding/decoding

---

*Integration audit: 2026-04-10*
