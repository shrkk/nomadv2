---
phase: 03.2-ui-redesign-live-activity-widget
plan: "02"
subsystem: design-system
tags: [token-sweep, ui-redesign, glassmorphic, color-tokens]
dependency_graph:
  requires: [03.2-01, 03.2-03]
  provides: [complete-token-sweep, zero-amber-cream-warmcard]
  affects: [all-user-facing-views]
tech_stack:
  added: []
  patterns:
    - floatingPillSurface() for JourneyPill and RecordingPill
    - innerCardSurface() for TripLogCard, StatsPillRow, TripPreviewCard
    - panelGlassSurface() / panelGradient() for all bottom sheets
    - GlassButtonStyle() for ContentView CTA
    - presentationBackground(Color.Nomad.panelBlack) on all sheets
key_files:
  created: []
  modified:
    - Nomad/Globe/GlobeView.swift
    - Nomad/Sheets/TripDetailSheet.swift
    - Nomad/Sheets/CountryDetailSheet.swift
    - Nomad/Sheets/ProfileSheet.swift
    - Nomad/Components/JourneyPill.swift
    - Nomad/Components/RecordingPill.swift
    - Nomad/Components/StatsPillRow.swift
    - Nomad/Components/TripLogCard.swift
    - Nomad/Components/CityThumbnailCard.swift
    - Nomad/Components/CityPhotoCarousel.swift
    - Nomad/Components/TripRouteMapView.swift
    - Nomad/Components/TemperatureNotchPill.swift
    - Nomad/Components/PhotoGalleryStrip.swift
    - Nomad/Components/DragStrip.swift
    - Nomad/Components/RoutePreviewPath.swift
    - Nomad/App/ContentView.swift
    - Nomad/Onboarding/WelcomeScreen.swift
    - Nomad/Onboarding/HandleScreen.swift
    - Nomad/Onboarding/LocationPermissionScreen.swift
    - Nomad/Onboarding/PhotosPermissionScreen.swift
    - Nomad/Onboarding/DiscoveryScopeScreen.swift
    - Nomad/Onboarding/SignUpScreen.swift
    - Nomad/Onboarding/HomeCityScreen.swift
    - Nomad/Onboarding/OnboardingView.swift
    - Nomad/Onboarding/HealthPermissionScreen.swift
decisions:
  - "White polygon fill (40%) + white stroke (60%) + 1pt lineWidth for globe country highlights"
  - "Onboarding CTAs use inverted glass: white accent background with panelBlack text"
  - "TripRouteMapView pin number text changed from white to black since pins are now white circles"
  - "RecordingPill destructive button wrapped with Capsule stroke (destructive 40%) + black 35% fill"
metrics:
  duration_minutes: 45
  completed_date: "2026-04-08"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 25
---

# Phase 03.2 Plan 02: Token Sweep (amber/cream/warmCard -> black/white glassmorphic) Summary

Complete visual redesign sweep across all 25 user-facing files — zero amber/cream/warmCard references remain in the Nomad/ directory. App renders entirely in the new black/white glassmorphic aesthetic established by Plan 01.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Globe chrome + Sheets + Pills token sweep | 34cf3f4 | GlobeView, TripDetailSheet, CountryDetailSheet, ProfileSheet, JourneyPill, RecordingPill |
| 2 | Supporting components token sweep | 60c81f5 | StatsPillRow, TripLogCard, CityThumbnailCard, CityPhotoCarousel, TripRouteMapView, TemperatureNotchPill, PhotoGalleryStrip, DragStrip, RoutePreviewPath, ContentView |
| 3 | Onboarding screens token sweep | ec1eb78 | WelcomeScreen, HandleScreen, LocationPermissionScreen, PhotosPermissionScreen, DiscoveryScopeScreen, SignUpScreen, HomeCityScreen, OnboardingView, HealthPermissionScreen |

## Verification Results

- Zero old token references in entire Nomad/ directory (cream/warmCard/amber all removed)
- Globe polygons: white 40% fill, white 60% stroke, 1pt lineWidth
- Globe pinpoints: UIColor.white.setFill()
- All 3 sheets have presentationBackground(panelBlack)
- RecordingPill: white dot, 0.8s/1.5x pulse

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TripRouteMapView pin number text color**
- **Found during:** Task 2
- **Issue:** Plan changed pin circle fill to white but kept white number text — invisible on white circle
- **Fix:** Changed pin number text from UIColor.white to UIColor.black
- **Files modified:** Nomad/Components/TripRouteMapView.swift
- **Commit:** 60c81f5

**2. [Rule 2 - Missing] RecordingPill Stop Trip destructive button variant**
- **Found during:** Task 1
- **Issue:** Original code had no button background; plan required explicit destructive Capsule style
- **Fix:** Added Capsule fill black.opacity(0.35) + destructive.opacity(0.40) stroke per UI-SPEC
- **Files modified:** Nomad/Components/RecordingPill.swift
- **Commit:** 34cf3f4

## Known Stubs

None.

## Threat Flags

None — pure visual token replacement, no new network endpoints, auth paths, file access patterns, or schema changes.

## Self-Check: PASSED

- All 25 files modified confirmed in git diff
- Commits 34cf3f4, 60c81f5, ec1eb78 present in git log
- grep returns 0 old token matches across entire Nomad/ directory
