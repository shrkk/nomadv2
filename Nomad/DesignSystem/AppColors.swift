import SwiftUI

// Color.Nomad namespace — canonical color palette for all phases.
// Source: D-05, D-06 (CONTEXT.md), UI-SPEC Color section.
extension Color {
    enum Nomad {
        // Globe background — deep space black with blue tint (#0A0A14)
        // Used ONLY for RealityKit/ARView scene background — never for panels or SwiftUI layers.
        static let globeBackground = Color(red: 0.039, green: 0.039, blue: 0.078)

        // Dominant (60%) — panel backgrounds, sheet surfaces, primary view backgrounds (#FAF8F4)
        static let cream = Color(red: 0.980, green: 0.973, blue: 0.957)

        // Secondary (30%) — card surfaces inside panels, inner containers (#F5F0E8)
        static let warmCard = Color(red: 0.961, green: 0.941, blue: 0.910)

        // Accent (10%) — country highlights on globe, interactive elements, buttons, key stats (#E8A44A)
        // Reserved uses: country polygon fills (60% opacity), outer glow (30% opacity),
        // panel gradient corners, button labels/CTAs, key stat values, SF Symbol tints.
        // Do NOT use for body text, captions, or non-interactive decorative elements.
        static let amber = Color(red: 0.910, green: 0.643, blue: 0.290)

        // Destructive actions only — not applicable in Phase 1 (#D94F3D)
        static let destructive = Color(red: 0.851, green: 0.310, blue: 0.239)

        // Globe background star particles — used at 15–40% opacity
        static let star = Color.white
    }
}
