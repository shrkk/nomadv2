---
phase: 01-foundation-spikes-globe-shell
plan: 01
subsystem: ui
tags: [swiftui, firebase, firestore, firebase-auth, custom-fonts, playfair-display, inter, design-system, xcode, spm]

# Dependency graph
requires: []
provides:
  - AppFont enum with title/subheading/body/caption/buttonLabel (4 sizes, 2 weights, Playfair Display + Inter)
  - Color.Nomad namespace with 6 palette colors (globeBackground, cream, warmCard, amber, destructive, star)
  - PanelGradientModifier — reusable dual-corner radial amber gradient + grain noise overlay
  - Firebase iOS SDK 12.11.0 via SPM (FirebaseCore, FirebaseAuth, FirebaseFirestore)
  - FirebaseService stub with async writeStubUser/readStubUser for INFRA-03 validation
  - Nomad.xcodeproj — iOS 18 target, com.nomad.app bundle ID, simulator-enabled
  - Info.plist UIAppFonts registration for all 4 font files
affects:
  - 01-02 (RealityKit globe — uses AppFont, AppColors, PanelGradient)
  - 01-03 (bottom sheet spike — uses PanelGradient, AppFont)
  - 02 (data and auth — uses FirebaseService pattern, AppDelegate adaptor)
  - all subsequent phases (consume AppFont, AppColors, PanelGradient)

# Tech tracking
tech-stack:
  added:
    - Firebase iOS SDK 12.11.0 (SPM) — FirebaseCore, FirebaseAuth, FirebaseFirestore
    - Playfair Display (OTF, Regular + SemiBold) — bundled from Google Fonts
    - Inter (TTF, Regular + SemiBold) — bundled from Google Fonts
  patterns:
    - AppFont enum — canonical font access via static methods, not Font extensions
    - Color.Nomad nested enum — all palette colors in one namespace
    - ViewModifier pattern for PanelGradient — applied as .panelGradient() on any View
    - UIApplicationDelegateAdaptor pattern for Firebase init in SwiftUI app lifecycle

key-files:
  created:
    - Nomad.xcodeproj/project.pbxproj
    - Nomad.xcodeproj/xcshareddata/xcschemes/Nomad.xcscheme
    - Nomad/App/NomadApp.swift
    - Nomad/App/AppDelegate.swift
    - Nomad/App/ContentView.swift
    - Nomad/DesignSystem/AppFont.swift
    - Nomad/DesignSystem/AppColors.swift
    - Nomad/DesignSystem/PanelGradient.swift
    - Nomad/Firebase/FirebaseService.swift
    - Nomad/Info.plist
    - Nomad/Resources/PlayfairDisplay-Regular.otf
    - Nomad/Resources/PlayfairDisplay-SemiBold.otf
    - Nomad/Resources/Inter-Regular.ttf
    - Nomad/Resources/Inter-SemiBold.ttf
    - Nomad/Resources/grain-noise.png
    - .gitignore
  modified: []

key-decisions:
  - "AppFont has 5 methods (title/subheading/body/caption/buttonLabel), not 6 — largeTitle(34pt) removed per UI-SPEC 4-size maximum rule"
  - "Firebase SPM minimum version pinned to 12.11.0 upToNextMajorVersion per RESEARCH.md recommendation"
  - "Grain noise generated programmatically as 200x200 grayscale PNG (no Metal shader needed for Phase 1 spike)"
  - "GoogleService-Info.plist gitignored as defense-in-depth; each developer downloads their own from Firebase Console"
  - "SUPPORTED_PLATFORMS set to iphoneos iphonesimulator explicitly to enable simulator destinations in xcodebuild"

patterns-established:
  - "AppFont pattern: static factory methods on enum, consumed as AppFont.title() throughout all phases"
  - "Color.Nomad pattern: nested enum extension on Color, consumed as Color.Nomad.amber throughout all phases"
  - "PanelGradient pattern: ViewModifier applied via .panelGradient() extension on View"
  - "Firebase init pattern: UIApplicationDelegateAdaptor(AppDelegate.self) in App struct, FirebaseApp.configure() in AppDelegate"

requirements-completed: [DSYS-01, DSYS-02, DSYS-03, DSYS-05, INFRA-03]

# Metrics
duration: 12min
completed: 2026-04-04
---

# Phase 01 Plan 01: Design System Foundation & Firebase Connectivity Summary

**AppFont (5 methods, Playfair Display + Inter), Color.Nomad palette, PanelGradient modifier, and Firebase 12.11.0 SPM wired into an iOS 18 Xcode project that builds clean**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-04T22:49:37Z
- **Completed:** 2026-04-04T23:01:37Z
- **Tasks:** 2
- **Files modified:** 16

## Accomplishments

- Created greenfield Nomad.xcodeproj targeting iOS 18 (com.nomad.app) with simulator support — builds with zero errors
- Implemented canonical design system: AppFont (5 static methods), Color.Nomad (6 palette colors), PanelGradientModifier (dual radial amber gradients + grain)
- Bundled and registered 4 font files (Playfair Display Regular/SemiBold OTF, Inter Regular/SemiBold TTF) with verified PostScript names
- Added Firebase iOS SDK 12.11.0 via SPM with FirebaseCore, FirebaseAuth, FirebaseFirestore — packages resolved and linked
- Implemented FirebaseService with async writeStubUser/readStubUser targeting stub-user-01 document for INFRA-03 validation

## Task Commits

1. **Task 1: Xcode project, fonts, AppFont + AppColors** — `436812f` (feat)
2. **Task 2: Firebase SPM, AppDelegate, FirebaseService stub** — `ef72038` (feat)

## Files Created/Modified

- `Nomad.xcodeproj/project.pbxproj` — Xcode project with iOS 18 target, SPM Firebase references, simulator support
- `Nomad.xcodeproj/xcshareddata/xcschemes/Nomad.xcscheme` — shared build scheme enabling iOS Simulator destinations
- `Nomad/App/NomadApp.swift` — SwiftUI App entry with @UIApplicationDelegateAdaptor
- `Nomad/App/AppDelegate.swift` — UIApplicationDelegate calling FirebaseApp.configure()
- `Nomad/App/ContentView.swift` — Phase 1 stub demonstrating all design tokens on PanelGradient
- `Nomad/DesignSystem/AppFont.swift` — AppFont enum with 5 static font methods + DEBUG FontValidationView
- `Nomad/DesignSystem/AppColors.swift` — Color.Nomad extension with 6 palette colors
- `Nomad/DesignSystem/PanelGradient.swift` — PanelGradientModifier + .panelGradient() View extension
- `Nomad/Firebase/FirebaseService.swift` — FirebaseService with writeStubUser/readStubUser async throws
- `Nomad/Info.plist` — UIAppFonts array with all 4 font file registrations
- `Nomad/Resources/PlayfairDisplay-Regular.otf` — PostScript name: PlayfairDisplay-Regular
- `Nomad/Resources/PlayfairDisplay-SemiBold.otf` — PostScript name: PlayfairDisplay-SemiBold
- `Nomad/Resources/Inter-Regular.ttf` — PostScript name: Inter-Regular
- `Nomad/Resources/Inter-SemiBold.ttf` — PostScript name: Inter-SemiBold
- `Nomad/Resources/grain-noise.png` — 200x200 programmatically generated grayscale noise tile
- `.gitignore` — GoogleService-Info.plist excluded (defense-in-depth), standard Xcode/SPM ignores

## Decisions Made

- **AppFont 5-method contract (not 6):** The PLAN.md action specified a `largeTitle()` method at 34pt, but the UI-SPEC AppFont Implementation Contract explicitly removed it: "LargeTitle (34pt) removed to comply with 4-size maximum." The UI-SPEC is the approved design contract. Implemented per UI-SPEC. The plan's acceptance criteria still referenced largeTitle but the UI-SPEC takes precedence as the more recently reviewed artifact.
- **Firebase version pinned to 12.11.0:** Per RESEARCH.md recommendation — latest as of 2026-04-04, upToNextMajorVersion allows patch updates.
- **Grain noise PNG generated programmatically:** 200x200 grayscale noise created via Python stdlib (zlib/struct) — no external tools needed, consistent across environments, seeded for reproducibility (seed=42).
- **SUPPORTED_PLATFORMS = "iphoneos iphonesimulator":** Required to expose iOS Simulator destinations; project initially showed only Mac/device targets due to single-platform setting.

## Deviations from Plan

### Design Contract Conflict

**[UI-SPEC Override] AppFont: 5 methods instead of 6 — largeTitle() not implemented**
- **Found during:** Task 1 review of acceptance criteria vs UI-SPEC
- **Conflict:** PLAN.md action specified largeTitle() at 34pt; UI-SPEC §AppFont Implementation Contract explicitly states "largeTitle (34pt) removed to comply with 4-size maximum; Title (28pt) is the top of the scale"
- **Resolution:** UI-SPEC is the approved design contract reviewed by the checker. Implemented 5-method contract per UI-SPEC.
- **Files modified:** Nomad/DesignSystem/AppFont.swift
- **Note:** Plan acceptance criteria checks for largeTitle but UI-SPEC is authoritative. Checker sign-off on UI-SPEC (Dimension 4 Typography: PASS) confirms this is the correct shape.

---

**Total deviations:** 1 (UI-SPEC override — not a bug fix, a deliberate contract alignment)
**Impact on plan:** All downstream phases that consume AppFont will use the 5-method contract. No largeTitle needed until explicitly re-requested.

### Auto-fixed Build Issues

**[Rule 3 - Blocking] Added SUPPORTED_PLATFORMS to expose iOS Simulator destinations**
- **Found during:** Task 1 verification (xcodebuild build step)
- **Issue:** project.pbxproj had SUPPORTED_PLATFORMS = iphoneos — simulator destinations invisible to xcodebuild
- **Fix:** Changed to SUPPORTED_PLATFORMS = "iphoneos iphonesimulator" in both Debug and Release target configs
- **Files modified:** Nomad.xcodeproj/project.pbxproj
- **Verification:** xcodebuild -showdestinations listed iPhone 17 simulator; build succeeded
- **Committed in:** 436812f (Task 1 commit)

## Issues Encountered

- Xcode 26.2 (SDK 26.2 = iOS 26) is installed — no iPhone 16 simulator exists, only iPhone 17 and newer. Used iPhone 17 simulator for all xcodebuild commands. This is expected and does not affect production targets (IPHONEOS_DEPLOYMENT_TARGET = 18.0 remains correct).

## Known Stubs

- `Nomad/Firebase/FirebaseService.swift` — writeStubUser and readStubUser compile successfully but require GoogleService-Info.plist + Firestore test mode to execute at runtime. This is intentional per INFRA-03 design: stub validates compilation and API shape. Runtime validation requires user Firebase Console setup (see User Setup Required below).
- `Nomad/App/ContentView.swift` — displays hardcoded "5 countries visited" and stub UI text. This is intentional for Phase 1 design token validation only; real data wired in later phases.

## User Setup Required

Firebase Console configuration is required before runtime Firebase validation (INFRA-03):

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Register iOS app with bundle ID `com.nomad.app`
3. Download `GoogleService-Info.plist` → place at `Nomad/GoogleService-Info.plist` (gitignored)
4. Enable Firestore Database in test mode (Firebase Console → Firestore Database → Create database → Start in test mode)
5. Run app on simulator — console should log successful Firestore write/read

**Without GoogleService-Info.plist:** App crashes on launch (FirebaseApp.configure() cannot find configuration). This is expected behavior documented in the threat model.

## Next Phase Readiness

- Design system (AppFont, AppColors, PanelGradient) is ready for all subsequent phases — canonical contracts established
- Firebase SDK linked and compiling — pending user GoogleService-Info.plist for runtime validation
- Xcode project structure established with correct group layout (App/, DesignSystem/, Firebase/, Resources/)
- No blockers for Plan 02 (RealityKit globe spike) or Plan 03 (stacked sheets spike)

---
*Phase: 01-foundation-spikes-globe-shell*
*Completed: 2026-04-04*
