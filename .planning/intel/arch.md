---
updated_at: "2026-04-10T00:00:00Z"
---

## Architecture Overview

Native iOS travel journaling app using SwiftUI + MKMapView globe with Firebase backend. Two targets: the main Nomad app and a NomadLiveActivity widget extension. A small Firebase Cloud Functions project handles auth cleanup triggers.

## Key Components

| Component | Path | Responsibility |
|-----------|------|---------------|
| NomadApp | Nomad/App/NomadApp.swift | App entry point; auth-gated routing (loading/onboarding/globe) |
| GlobeView | Nomad/Globe/GlobeView.swift | Main screen: MKMapView 3D globe with trip pins, route overlays, trip recording |
| GlobeViewModel | Nomad/Globe/GlobeViewModel.swift | Globe state: loads GeoJSON countries, fetches trips/visited codes from Firestore |
| AuthManager | Nomad/Auth/AuthManager.swift | Firebase Auth state listener; email/password + Google Sign-In |
| UserService | Nomad/Auth/UserService.swift | Firestore user doc CRUD, handle uniqueness, onboarding completion |
| TripService | Nomad/Data/TripService.swift | Trip finalization: route simplification, POI categorization, Firestore write |
| LocationManager | Nomad/Location/LocationManager.swift | Background GPS recording via CLLocationUpdate.liveUpdates(), SwiftData buffering |
| VisitMonitor | Nomad/Location/VisitMonitor.swift | Geofence exit detection + local notification for trip prompts |
| RouteSimplifier | Nomad/Location/RouteSimplifier.swift | Ramer-Douglas-Peucker GPS trace simplification |
| PlaceCategoryService | Nomad/Data/PlaceCategoryService.swift | MKLocalPointsOfInterestRequest POI categorization (6 dimensions) |
| FirestoreSchema | Nomad/Data/FirestoreSchema.swift | Type-safe Firestore path constants and field keys |
| CountryDetailSheet | Nomad/Sheets/CountryDetailSheet.swift | Country detail view: city clusters, photo gallery, trip logs |
| DesignSystem | Nomad/DesignSystem/ | AppColors, AppFont, PanelGradient tokens |
| LiveActivity | NomadLiveActivity/ | Lock screen widget showing trip distance, elapsed time, location |
| Cloud Functions | functions/src/index.ts | Auth trigger: cleanup user/username docs on account deletion |

## Data Flow

NomadApp (auth gate) -> GlobeView (MKMapView globe) -> pin tap -> CountryDetailSheet -> TripDetailSheet

Trip Recording: JourneyPill/ProfileSheet -> LocationManager.startRecording() -> CLLocationUpdate.liveUpdates() -> RoutePoint (SwiftData) -> TripService.finalizeTrip() -> Firestore

Auth: AuthManager (Firebase Auth listener) -> authState enum -> NomadApp routing (onboarding vs globe)

Firestore Schema: users/{uid} (profile) -> users/{uid}/trips/{tripId} (trip docs) -> users/{uid}/trips/{tripId}/routePoints (GPS data); usernames/{handle} (uniqueness)

## Conventions

- @Observable + @MainActor pattern for view models (Swift 6 concurrency)
- SwiftData for local GPS point buffering (RoutePoint, TripLocal models)
- Firestore for server-authoritative trip and user data
- Design tokens centralized in DesignSystem/ (AppColors, AppFont, PanelGradient)
- Sheet-based navigation: ProfileSheet, CountryDetailSheet, TripDetailSheet
- File organization: App/, Globe/, Auth/, Data/, Location/, Onboarding/, Sheets/, Components/, DesignSystem/, GeoJSON/, Firebase/
- Inter font family throughout (Regular 400, SemiBold 600)
- Black/white glassmorphic color palette with panel gradients
