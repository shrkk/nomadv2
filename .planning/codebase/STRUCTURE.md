# Codebase Structure

**Analysis Date:** 2026-04-10

## Directory Layout

```
nomadv2/
├── Nomad/                      # Main iOS app target
│   ├── App/                    # Root app entry, content view, delegate
│   ├── Auth/                   # Firebase auth management
│   ├── Components/             # Reusable UI components
│   ├── Data/                   # Services, models, Firestore schema
│   │   └── Models/             # TripDocument, RoutePoint, TripLocal
│   ├── DesignSystem/           # Color tokens, typography, styling
│   ├── Firebase/               # Firebase initialization
│   ├── GeoJSON/                # Country boundary parsing
│   ├── Globe/                  # Globe view and view model
│   ├── Location/               # GPS recording, route simplification
│   ├── Onboarding/             # Multi-step onboarding screens
│   ├── Resources/              # JSON, strings, data assets
│   ├── Sheets/                 # Bottom sheets (trip detail, country detail, profile)
│   ├── Assets.xcassets/        # App icons, colors, images
│   ├── GoogleService-Info.plist # Firebase config (NOT committed)
│   ├── Info.plist              # App configuration
│   └── Nomad.entitlements      # Capabilities (location, health, photos)
├── NomadLiveActivity/          # ActivityKit widget for trip recording
│   ├── TripActivityAttributes.swift
│   ├── TripLiveActivity.swift
│   ├── NomadLiveActivityBundle.swift
│   └── Assets.xcassets/
├── Nomad.xcodeproj/            # Xcode project file (modified frequently)
├── functions/                  # Firebase Cloud Functions (Node.js)
│   ├── src/
│   │   └── index.ts            # onUserDeleted trigger
│   ├── package.json
│   └── tsconfig.json
├── .planning/                  # GSD planning documents (not code)
├── .firebaserc                 # Firebase project config
├── firebase.json               # Firebase deployment config
├── firestore.rules             # Firestore security rules
└── .gitignore                  # Excludes .env, build artifacts
```

## Directory Purposes

**Nomad/App:**
- Purpose: Root app entry point, main scene setup, content routing
- Contains: NomadApp.swift (@main), AppDelegate.swift, ContentView.swift (phase 1 stub)
- Key files: `NomadApp.swift` (auth-gated routing), `AppDelegate.swift` (lifecycle)

**Nomad/Auth:**
- Purpose: Firebase auth state management, sign-in/sign-up orchestration
- Contains: AuthManager.swift (state listener, sign-in/up methods), UserService.swift (user document reads)
- Key files: `AuthManager.swift` (@Observable auth state), `UserService.swift` (Firestore user fetches)

**Nomad/Components:**
- Purpose: Reusable, composable UI elements (cards, pills, galleries, maps)
- Contains: 11 component files (TripLogCard, StatsPillRow, PhotoGalleryStrip, RoutePreviewPath, etc.)
- Key files: `RoutePreviewPath.swift` (MapKit polyline rendering), `TripLogCard.swift` (trip summary display), `PhotoGalleryStrip.swift` (swipeable photo carousel)

**Nomad/Data:**
- Purpose: Service layer (Firestore, trip logic, categorization) and type-safe schema
- Contains: TripService.swift, PlaceCategoryService.swift, WeatherService.swift, FirestoreSchema.swift
- Key files: `TripService.swift` (finalize, fetch, batch sync), `FirestoreSchema.swift` (path helpers), `Models/` subdirectory (TripDocument, RoutePoint, TripLocal)

**Nomad/Data/Models:**
- Purpose: Data models for Firestore documents and local storage
- Contains: TripDocument.swift (Firestore trip), RoutePoint.swift (@Model for SwiftData), TripLocal.swift (local recording state)
- Key files: `TripDocument.swift` (server model with manual decoding), `RoutePoint.swift` (GPS point with SwiftData @Model macro)

**Nomad/DesignSystem:**
- Purpose: Canonical color palette, typography, and style tokens
- Contains: AppColors.swift (Color.Nomad namespace), AppFont.swift (font definitions), PanelGradient.swift (glass panel styling)
- Key files: `AppColors.swift` (globeBackground, panelBlack, textPrimary, accent), `AppFont.swift` (title, body, caption sizes)

**Nomad/Firebase:**
- Purpose: Firebase initialization and common setup
- Contains: FirebaseService.swift (singleton setup)
- Key files: `FirebaseService.swift` (minimal — actual auth/DB work in AuthManager and TripService)

**Nomad/GeoJSON:**
- Purpose: Parse and render country boundaries for globe overlay
- Contains: GeoJSONParser.swift (load from Bundle), CountryFeature.swift (model for parsed features)
- Key files: `GeoJSONParser.swift` (async load + decode), `CountryFeature.swift` (geometry, properties)

**Nomad/Globe:**
- Purpose: Interactive 3D globe rendering and country/trip pinpoint management
- Contains: GlobeView.swift (MapKit UIViewRepresentable), GlobeViewModel.swift (state + fetches), GlobePinpoint.swift (trip annotation), GlobeCountryOverlay.swift (tap handler)
- Key files: `GlobeView.swift` (hybridFlyover map rendering), `GlobeViewModel.swift` (@Observable state, trip/country fetching), `GlobePinpoint.swift` (TripAnnotation views)

**Nomad/Location:**
- Purpose: Background GPS recording, route simplification, dwell detection
- Contains: LocationManager.swift (CLLocationUpdate stream + Live Activity), RouteSimplifier.swift (Ramer-Douglas-Peucker), VisitMonitor.swift (pause detection)
- Key files: `LocationManager.swift` (background session, recording lifecycle), `RouteSimplifier.swift` (simplify + coordinate extraction), `VisitMonitor.swift` (dwell detection for places)

**Nomad/Onboarding:**
- Purpose: Multi-step user onboarding flow with permissions and data collection
- Contains: 10 screen files (WelcomeScreen, SignUpScreen, HandleScreen, etc.), OnboardingCoordinator.swift (step state machine), OnboardingView.swift (router)
- Key files: `OnboardingCoordinator.swift` (step enum, data accumulation), `OnboardingView.swift` (step-based rendering), `HomeCityScreen.swift` (Firestore write on completion)

**Nomad/Resources:**
- Purpose: Static assets (countries GeoJSON, strings, configuration data)
- Contains: JSON files, string bundles
- Key files: Countries GeoJSON file (loaded by GeoJSONParser)

**Nomad/Sheets:**
- Purpose: Modal bottom sheets overlaid on globe view
- Contains: CountryDetailSheet.swift (cities in country + photo gallery), TripDetailSheet.swift (route map + stats + photos), ProfileSheet.swift (user profile), TravelerPassportStub.swift (future)
- Key files: `TripDetailSheet.swift` (DETAIL-01 route map, DETAIL-02 stats), `CountryDetailSheet.swift` (city clustering + photo/temp loading)

**NomadLiveActivity:**
- Purpose: ActivityKit widget displaying live trip recording status in Dynamic Island and Lock Screen
- Contains: TripActivityAttributes.swift (activity state model), TripLiveActivity.swift (widget body), CompactLeadingView, ExpandedIslandView, LockScreenBannerView
- Key files: `TripLiveActivity.swift` (ActivityConfiguration + view regions), `TripActivityAttributes.swift` (ContentState with elapsed, distance)

**functions/src:**
- Purpose: Firebase Cloud Functions for cleanup and server-side logic
- Contains: index.ts (onUserDeleted trigger for cascading document deletion)
- Key files: `index.ts` (auth.user().onDelete handler)

**Nomad.xcodeproj:**
- Purpose: Xcode project configuration
- Key files: `project.pbxproj` (frequently modified, contains build settings, file references)

## Key File Locations

**Entry Points:**
- `Nomad/App/NomadApp.swift`: @main app struct, FirebaseApp.configure(), auth state routing
- `Nomad/App/AppDelegate.swift`: UIApplicationDelegate lifecycle hooks
- `NomadLiveActivity/NomadLiveActivityBundle.swift`: ActivityKit entry point

**Configuration:**
- `Nomad/Info.plist`: App metadata, permissions, capabilities
- `Nomad/Nomad.entitlements`: Capabilities (location always/whenInUse, health, photos)
- `.firebaserc`: Firebase project ID selection
- `firebase.json`: Firebase deployment targets

**Core Logic:**
- `Nomad/Auth/AuthManager.swift`: Auth state listener, sign-in/up
- `Nomad/Data/TripService.swift`: Trip finalization, Firestore persistence
- `Nomad/Location/LocationManager.swift`: GPS recording pipeline
- `Nomad/Globe/GlobeViewModel.swift`: Globe state, trip fetching, country focus

**Design System:**
- `Nomad/DesignSystem/AppColors.swift`: Color.Nomad token namespace
- `Nomad/DesignSystem/AppFont.swift`: Font size/weight definitions
- `Nomad/DesignSystem/PanelGradient.swift`: Glassmorphic panel styling

**Testing:**
- No test files present (testing patterns not yet established)

## Naming Conventions

**Files:**
- PascalCase for Swift source files (e.g., `GlobeViewModel.swift`, `TripDetailSheet.swift`)
- Suffixes indicate type: `ViewModel`, `View`, `Sheet`, `Service`, `Manager`, `Coordinator`
- Models grouped in `Models/` subdirectory (e.g., `Models/TripDocument.swift`)

**Directories:**
- PascalCase for feature directories (e.g., `Globe`, `Onboarding`, `Components`)
- Lowercase for generic directories (e.g., `models`, `src`)
- Related concepts grouped by domain, not by type

**Types & Functions:**
- PascalCase for struct/class/enum names (e.g., `GlobeViewModel`, `TripDocument`, `AuthState`)
- camelCase for function/method names (e.g., `startRecording()`, `fetchTrips()`, `simplifyRoute()`)
- camelCase for properties (e.g., `isRecording`, `routeCoordinates`, `focusedCountryCode`)
- SCREAMING_SNAKE_CASE for constants (e.g., `testSeattleRoute`, `batchSize = 400`)

**Firestore Paths:**
- `users/{uid}`: User profile document
- `users/{uid}/trips/{tripId}`: Trip document
- `users/{uid}/trips/{tripId}/routePoints`: Route point subcollection
- `usernames/{handle}`: Username reservation document

## Where to Add New Code

**New Feature:**
- Primary code: `Nomad/{FeatureName}/`
- ViewModel: `Nomad/{FeatureName}/{FeatureName}ViewModel.swift`
- Views: `Nomad/{FeatureName}/{FeatureName}View.swift` and components in `Nomad/Components/`
- Tests: Create `Nomad/{FeatureName}/{FeatureName}Tests.swift` (when test infrastructure is added)

**New Component/Module:**
- Implementation: `Nomad/Components/{ComponentName}.swift` if reusable; otherwise in feature-specific folder
- Pattern: Standalone struct conforming to View, accept dependencies as constructor parameters
- Example: New chart component → `Nomad/Components/StatChartView.swift`

**Utilities:**
- Shared helpers: `Nomad/Location/` (RouteSimplifier, VisitMonitor patterns), `Nomad/Data/` (service layer)
- Design tokens: `Nomad/DesignSystem/` (AppColors, AppFont patterns)
- Type-safe paths: `Nomad/Data/FirestoreSchema.swift` (extend with new collection paths)

**Firebase Functions:**
- Cloud Functions: `functions/src/{name}.ts` (one export per file)
- Pattern: Async handler with error logging, database batch operations for consistency
- Deployment: `firebase deploy --only functions`

## Special Directories

**Nomad/Assets.xcassets:**
- Purpose: App icons, color sets, image assets
- Generated: Yes (Xcode asset catalog)
- Committed: Yes (source files, not compiled)
- Key contents: AppIcon, AccentColor, app images

**NomadLiveActivity/Assets.xcassets:**
- Purpose: ActivityKit widget assets
- Generated: Yes (Xcode asset catalog)
- Committed: Yes

**.planning/:**
- Purpose: GSD planning documents (architecture, structure, conventions, concerns)
- Generated: Yes (by /gsd-map-codebase)
- Committed: Yes
- Not part of app bundle

**Nomad.xcodeproj/:**
- Purpose: Xcode project configuration
- Generated: Partially (Xcode modifies frequently)
- Committed: Yes (project.pbxproj tracked despite modifications)
- Do not manually edit unless necessary

**GoogleService-Info.plist:**
- Purpose: Firebase configuration (API key, project ID, bundle ID)
- Generated: Yes (downloaded from Firebase Console)
- Committed: NO — add to `.gitignore`
- Required for: Firebase initialization

**functions/lib/**
- Purpose: Compiled TypeScript output
- Generated: Yes (`npm run build`)
- Committed: No

---

*Structure analysis: 2026-04-10*
