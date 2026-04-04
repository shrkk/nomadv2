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
//
// @MainActor isolation satisfies Swift 6 strict concurrency for @Observable viewModel.

@MainActor
struct GlobeView: View {
    @State private var viewModel = GlobeViewModel()
    @State private var globeEntity: ModelEntity?
    @State private var textureApplied: Bool = false

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
                }
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
