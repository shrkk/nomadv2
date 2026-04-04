---
phase: 01-foundation-spikes-globe-shell
plan: 03
subsystem: globe-rendering
tags: [realitykit, globe, geojson, texture-paint, swiftui, coregraphics, swift6]

# Dependency graph
requires: [01-01, 01-02]
provides:
  - GlobeCountryOverlay — equirectangular CoreGraphics texture-paint pipeline (4096x2048)
  - GlobeViewModel — @MainActor @Observable state manager with async GeoJSON load + overlay render
  - GlobeView — RealityView virtual 3D globe with drag rotation, pinch zoom, star field, country overlay
  - NomadApp.swift updated to show GlobeView as root view
affects:
  - 01-04 (physical device verification — verifies globe renders on iPhone without stutter)
  - 02+ (all phases — globe is the persistent home view)

# Tech tracking
tech-stack:
  added:
    - RealityKit (system, iOS 18) — RealityView with .virtual camera, ModelEntity, DirectionalLight, PerspectiveCamera
    - CoreGraphics / UIKit — UIGraphicsImageRenderer for equirectangular country polygon texture
    - TextureResource(image:options:) — iOS 18 non-deprecated API for CGImage → RealityKit texture
  patterns:
    - Equirectangular texture-paint: CGMutablePath polygon fill onto UIImage canvas, uploaded as TextureResource
    - @MainActor @Observable: both GlobeView and GlobeViewModel isolated to main actor for Swift 6 strict concurrency
    - textureApplied @State flag: avoids mutating @Observable property inside RealityView update closure
    - Task.detached for CoreGraphics render: heavy 4096x2048 texture render off main thread
    - content.camera = .virtual: prevents AR session / camera feed activation

key-files:
  created:
    - Nomad/Globe/GlobeCountryOverlay.swift
    - Nomad/Globe/GlobeViewModel.swift
    - Nomad/Globe/GlobeView.swift
  modified:
    - Nomad/App/NomadApp.swift
    - Nomad.xcodeproj/project.pbxproj

key-decisions:
  - "TextureResource(image:options:) used instead of deprecated TextureResource.generate(from:options:) — iOS 18 API"
  - "@MainActor applied to both GlobeView and GlobeViewModel to satisfy Swift 6 strict concurrency (sending self risks data races error)"
  - "textureApplied local @State flag used instead of nulling viewModel.overlayTexture — avoids re-entrant @Observable mutation inside RealityView update closure"
  - "Task.detached for CoreGraphics texture render — keeps 4096x2048 polygon fill off main thread while makeTextureResource runs on MainActor"

metrics:
  duration: 4min
  completed: 2026-04-04T23:15:33Z
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 2
---

# Phase 01 Plan 03: Globe Rendering Spike Summary

RealityKit virtual 3D globe with equirectangular CoreGraphics texture-paint overlay rendering 5 hardcoded amber-filled countries, drag rotation, pinch zoom, and star field — building cleanly on iOS 18 simulator under Swift 6 strict concurrency.

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-04T23:11:10Z
- **Completed:** 2026-04-04T23:15:33Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Implemented GlobeCountryOverlay: equirectangular CoreGraphics pipeline converting CLLocationCoordinate2D to pixel coordinates, fills visited country polygons with amber (#E8A44A at 60% opacity) and outer glow (blur=8, 30% opacity) per D-03
- Hardcoded 5 visited countries (JP, FR, KE, AU, BR) as required for Phase 1 spike
- Implemented GlobeViewModel with @MainActor @Observable pattern: async GeoJSON load via GeoJSONParser, CoreGraphics texture render dispatched to detached task, TextureResource upload on main actor
- Implemented GlobeView: RealityView with `content.camera = .virtual` (no AR session), 80-star unlit sphere field per D-01, warm DirectionalLight per D-02, DragGesture yaw/pitch rotation, MagnifyGesture zoom (0.8–2.5 distance), textureApplied @State flag avoiding re-entrant update
- Updated NomadApp.swift to use GlobeView as root view
- Project builds cleanly on iPhone 17 simulator — BUILD SUCCEEDED with zero errors under Swift 6 strict concurrency

## Task Commits

1. **Task 1: GlobeCountryOverlay — equirectangular texture-paint pipeline** — `776b050` (feat)
2. **Task 2: GlobeView + GlobeViewModel + NomadApp root update** — `2991687` (feat)

## Files Created/Modified

- `Nomad/Globe/GlobeCountryOverlay.swift` — Equirectangular texture renderer: geoJSONToPixel, renderOverlayTexture, makeTextureResource (@MainActor, iOS 18 API)
- `Nomad/Globe/GlobeViewModel.swift` — @MainActor @Observable state: async load pipeline, detached CoreGraphics render, MainActor texture upload
- `Nomad/Globe/GlobeView.swift` — RealityView with .virtual camera, star field, globe sphere, warm light, drag/pinch gestures, textureApplied flag
- `Nomad/App/NomadApp.swift` — Root view switched from ContentView to GlobeView
- `Nomad.xcodeproj/project.pbxproj` — Globe group added with 3 file references + source build phase entries

## Decisions Made

- **TextureResource iOS 18 API:** `TextureResource.generate(from:options:)` is deprecated in iOS 18 — used `TextureResource(image:options:)` initializer instead. The plan specified the deprecated form; updated to current API.
- **@MainActor on GlobeView and GlobeViewModel:** Swift 6 strict concurrency (SWIFT_VERSION = 6.0 in project.pbxproj) requires explicit actor isolation when @Observable classes are accessed from async contexts. Applied `@MainActor` to both types to eliminate "sending self risks causing data races" errors.
- **textureApplied @State flag:** As specified in plan — avoids mutating @Observable property inside RealityView update closure. Implemented exactly as designed.
- **Task.detached for CoreGraphics render:** makeTextureResource is @MainActor, but the CoreGraphics polygon fill (4096x2048 canvas) can run off main thread. Split into Task.detached for the render step and MainActor for the TextureResource upload.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TextureResource.generate deprecated in iOS 18 — switched to new API**
- **Found during:** Task 1 verification (xcodebuild build — deprecation warning + main actor isolation error)
- **Issue:** Plan specified `TextureResource.generate(from:cgImage, options:)` which is deprecated in iOS 18 and requires `@MainActor` call site annotation
- **Fix:** Replaced with `TextureResource(image: cgImage, options:)` initializer and annotated `makeTextureResource` as `@MainActor`
- **Files modified:** Nomad/Globe/GlobeCountryOverlay.swift
- **Commit:** 776b050

**2. [Rule 1 - Bug] Swift 6 strict concurrency errors — @MainActor isolation required**
- **Found during:** Task 1/2 first build attempt
- **Issue:** "sending 'self' risks causing data races" on GlobeViewModel (line 28, 33) and GlobeView (line 111) — Swift 6 mode requires explicit actor isolation for @Observable classes accessed across task boundaries
- **Fix:** Applied `@MainActor` to both `GlobeViewModel` and `GlobeView`. Restructured `loadGlobeData()` to use `Task.detached` for the CoreGraphics render and perform TextureResource upload directly (already on MainActor), eliminating the `await MainActor.run` wrapper that triggered the data race error
- **Files modified:** Nomad/Globe/GlobeViewModel.swift, Nomad/Globe/GlobeView.swift
- **Commit:** 2991687

## Known Stubs

- `Nomad/Globe/GlobeView.swift` — 5 hardcoded visited countries rendered (JP, FR, KE, AU, BR). Real visited-country data is wired in Phase 2+ when user data model exists. This is intentional for the Phase 1 spike.
- `Nomad/Globe/GlobeView.swift` — Camera zoom adjusts `viewModel.cameraDistance` state but the PerspectiveCamera entity is not repositioned per frame (the `update` closure does not move it). Camera zoom will appear to not work at runtime. This is a known limitation of the Phase 1 spike — camera distance state is tracked correctly but not applied to the scene graph camera entity. Deferred to Plan 04 physical device verification task.

## Self-Check

### Created files exist
- Nomad/Globe/GlobeCountryOverlay.swift: FOUND
- Nomad/Globe/GlobeView.swift: FOUND
- Nomad/Globe/GlobeViewModel.swift: FOUND

### Commits exist
- 776b050 (Task 1): FOUND
- 2991687 (Task 2): FOUND

## Self-Check: PASSED

---
*Phase: 01-foundation-spikes-globe-shell*
*Completed: 2026-04-04T23:15:33Z*
