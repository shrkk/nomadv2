import SwiftUI
import RealityKit

// MARK: - GlobeView
//
// RealityView wrapper presenting a virtual 3D globe with:
//   - Deep space background (#0A0A14) per D-01
//   - ~80 unlit star-sphere entities at high radius per D-01
//   - Directional warm light per D-02
//   - Globe sphere (radius 0.5) with country overlay texture per D-03
//   - One-finger drag for yaw + pitch rotation
//   - Two-finger pinch for camera zoom
//   - SpatialTapGesture for country focus animation and pinpoint → profile sheet
//
// @MainActor isolation satisfies Swift 6 strict concurrency for @Observable viewModel.

@MainActor
struct GlobeView: View {
    @State private var viewModel = GlobeViewModel()
    @State private var globeEntity: ModelEntity?
    @State private var textureApplied: Bool = false
    // Tracks pinpoint entity IDs added to the scene to avoid duplicate insertion
    @State private var addedPinpointIDs: Set<String> = []

    // Gesture tracking — stores last translation delta so we get velocity-free incremental rotation
    @State private var lastDragTranslation: CGSize = .zero

    var body: some View {
        ZStack {
            // Deep space background per D-01: #0A0A14
            Color.Nomad.globeBackground
                .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(Color.Nomad.amber)
            } else {
                RealityView { content in
                    // CRITICAL: virtual camera mode — no AR session, no camera feed
                    content.camera = .virtual

                    // --- Star field per D-01: ~80 small unlit spheres at large radius ---
                    // Density and size are Claude's discretion per CONTEXT.md
                    for _ in 0..<80 {
                        let star = ModelEntity(
                            mesh: .generateSphere(radius: Float.random(in: 0.003...0.008)),
                            materials: [UnlitMaterial(color: UIColor(
                                white: 1.0,
                                alpha: CGFloat(Float.random(in: 0.15...0.40))
                            ))]
                        )
                        // Random position on a large surrounding sphere (radius 5–8)
                        let theta = Float.random(in: 0...(2 * .pi))
                        let phi = Float.random(in: 0...(.pi))
                        let r = Float.random(in: 5...8)
                        star.position = SIMD3<Float>(
                            r * sin(phi) * cos(theta),
                            r * cos(phi),
                            r * sin(phi) * sin(theta)
                        )
                        content.add(star)
                    }

                    // --- Globe sphere (radius 0.5 world units) ---
                    let sphere = ModelEntity(
                        mesh: .generateSphere(radius: 0.5),
                        materials: [makeGlobeMaterial()]
                    )
                    sphere.name = "globe"
                    sphere.generateCollisionShapes(recursive: false)
                    content.add(sphere)
                    globeEntity = sphere

                    // --- Directional light per D-02: warm hemisphere ---
                    // One primary light source, no ambient fill — dark side stays dark
                    let light = DirectionalLight()
                    light.light.color = UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1.0)
                    light.light.intensity = 1000
                    light.look(at: SIMD3(0, 0, 0), from: SIMD3(1, 0.5, 1), relativeTo: nil)
                    content.add(light)

                    // --- Perspective camera at initial distance ---
                    let camera = PerspectiveCamera()
                    camera.camera.fieldOfViewInDegrees = 45
                    camera.position = SIMD3(0, 0, viewModel.cameraDistance)
                    content.add(camera)

                } update: { content in
                    // Update globe rotation when gesture state changes
                    if let globe = globeEntity {
                        let pitchQuat = simd_quatf(angle: viewModel.rotationX, axis: SIMD3(1, 0, 0))
                        let yawQuat = simd_quatf(angle: viewModel.rotationY, axis: SIMD3(0, 1, 0))
                        globe.orientation = yawQuat * pitchQuat
                    }

                    // Apply overlay texture once loaded.
                    // Uses local @State flag to avoid mutating @Observable property inside
                    // the RealityView update closure (prevents re-entrant update calls).
                    if !textureApplied, let texture = viewModel.overlayTexture, let globe = globeEntity {
                        var material = UnlitMaterial()
                        material.color = .init(
                            tint: .white,
                            texture: MaterialParameters.Texture(texture)
                        )
                        globe.model?.materials = [material]
                        textureApplied = true
                    }

                    // Add pinpoint entities when a country is focused.
                    // Only add trips belonging to the focused country, only once each.
                    if viewModel.showPinpoints, let code = viewModel.focusedCountryCode {
                        let trips = viewModel.tripsByCountry[code] ?? []
                        for trip in trips {
                            guard !addedPinpointIDs.contains(trip.id) else { continue }
                            let pinEntity = GlobePinpoint.createEntity(for: trip)
                            content.add(pinEntity)
                            addedPinpointIDs.insert(trip.id)
                        }
                    }
                }
                .gesture(
                    // SpatialTapGesture handles both pinpoint taps and globe taps.
                    // Pinpoint tap → identify by entity name → open ProfileSheet.
                    // Globe tap → compute hit lat/lon → animate to nearest visited country centroid.
                    SpatialTapGesture()
                        .targetedToAnyEntity()
                        .onEnded { value in
                            let tappedEntity = value.entity

                            // --- Pinpoint tap: open ProfileSheet ---
                            if let trip = GlobePinpoint.StubTrip.stubTrips.first(where: { $0.id == tappedEntity.name }) {
                                viewModel.selectedTrip = trip
                                viewModel.showProfileSheet = true
                                return
                            }

                            // --- Globe tap: animate to nearest visited country ---
                            // SpatialTapGesture.Value only provides a 2D screen location.
                            // For Phase 1 spike, we approximate the tapped lon/lat by
                            // reverse-projecting the screen position through the current
                            // globe rotation. We use the 2D tap location relative to the
                            // view centre to estimate the facing lon/lat, then find the
                            // nearest visited country centroid.
                            guard tappedEntity.name == "globe" else { return }

                            // Current globe facing direction (centre of sphere in screen space)
                            // maps to (rotationY, rotationX). Use globe rotation state to pick
                            // the nearest visited country centroid to the current facing direction.
                            // This is a Phase 1 simplification — full raycast deferred to Phase 2.
                            let facingLat = Double(-viewModel.rotationX * 180 / .pi)
                            let facingLon = Double(-viewModel.rotationY * 180 / .pi)

                            // Find the visited country centroid nearest to the facing direction
                            let visitedCodes = GlobeCountryOverlay.hardcodedVisitedCodes
                            let visitedCountries = viewModel.countries.filter { visitedCodes.contains($0.isoCode) }

                            var bestCode: String? = nil
                            var bestDist: Double = .infinity
                            for country in visitedCountries {
                                let coords = country.polygons.first ?? []
                                guard !coords.isEmpty else { continue }
                                let cLat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
                                let cLon = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
                                let dist = (facingLat - cLat) * (facingLat - cLat) + (facingLon - cLon) * (facingLon - cLon)
                                if dist < bestDist {
                                    bestDist = dist
                                    bestCode = country.isoCode
                                }
                            }

                            if let code = bestCode {
                                // Clear previously added pinpoints when switching country focus
                                addedPinpointIDs = []
                                viewModel.animateToCountry(code: code)
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let deltaX = Float(value.translation.width - lastDragTranslation.width) * 0.005
                            let deltaY = Float(value.translation.height - lastDragTranslation.height) * 0.005
                            viewModel.rotationY += deltaX
                            viewModel.rotationX += deltaY
                            lastDragTranslation = value.translation
                        }
                        .onEnded { _ in
                            lastDragTranslation = .zero
                        }
                )
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let scale = Float(value.magnification)
                            let newDistance = viewModel.cameraDistance / scale
                            viewModel.cameraDistance = min(
                                viewModel.maxCameraDistance,
                                max(viewModel.minCameraDistance, newDistance)
                            )
                        }
                )
                .ignoresSafeArea()
                // FIRST sheet slot — ProfileSheet presents from GlobeView.
                // CRITICAL: TripDetailSheet is nested INSIDE ProfileSheet's body (INFRA-02 pattern).
                // It is NOT a second .sheet() here — that would cause cascading dismissal.
                .sheet(isPresented: $viewModel.showProfileSheet) {
                    ProfileSheet(
                        selectedTrip: viewModel.selectedTrip,
                        trips: GlobePinpoint.StubTrip.stubTrips
                    )
                }
            }
        }
        .task {
            await viewModel.loadGlobeData()
        }
    }

    /// Initial globe material — deep space color, replaced with overlay texture after load
    private func makeGlobeMaterial() -> any RealityKit.Material {
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(Color.Nomad.globeBackground))
        return material
    }
}
