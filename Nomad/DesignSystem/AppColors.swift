import SwiftUI

// Color.Nomad namespace — canonical color palette for all phases.
// Source: D-01 (CONTEXT.md), UI-SPEC Color section (Phase 03.2 redesign).
// Black/white glassmorphic token set (Phase 03.2 redesign).
extension Color {
    enum Nomad {
        // Globe background — deep space black with blue tint (#0A0A14) — UNCHANGED
        // Used ONLY for RealityKit/ARView scene background — never for panels or SwiftUI layers.
        static let globeBackground = Color(red: 0.039, green: 0.039, blue: 0.078)

        // Dominant (60%) — panel/sheet backgrounds (#0A0A0A)
        static let panelBlack = Color(red: 0.039, green: 0.039, blue: 0.039)

        // Primary text — pure white (#FFFFFF)
        static let textPrimary = Color.white

        // Secondary text — white 60% opacity
        static let textSecondary = Color.white.opacity(0.60)

        // Accent (10%) — active states, highlights, key stat values, button borders
        static let accent = Color.white

        // Destructive actions only (#D94F3D) — UNCHANGED
        static let destructive = Color(red: 0.851, green: 0.310, blue: 0.239)

        // Globe background star particles — UNCHANGED
        static let star = Color.white
    }
}
