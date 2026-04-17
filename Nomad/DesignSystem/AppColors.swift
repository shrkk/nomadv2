import SwiftUI
import UIKit

// Color.Nomad namespace — canonical color palette for all phases.
// Blue/navy/indigo palette derived from the Nomad poster design.
extension Color {
    enum Nomad {
        // Globe background — deepest navy (#020920)
        static let globeBackground = Color(hex: 0x020920)

        // Dominant (60%) — panel/sheet backgrounds — dark indigo (#0F0F28)
        static let panelBlack = Color(hex: 0x0F0F28)

        // Primary text — light lavender (#E1E2F0)
        static let textPrimary = Color(hex: 0xE1E2F0)

        // Secondary text — muted indigo (#8E92C6)
        static let textSecondary = Color(hex: 0x8E92C6)

        // Accent (10%) — active states, highlights, key stat values — periwinkle blue (#5E89DD)
        static let accent = Color(hex: 0x5E89DD)

        // Destructive actions only (#D94F3D) — UNCHANGED
        static let destructive = Color(red: 0.851, green: 0.310, blue: 0.239)

        // Globe background star particles — light blue (#C8D7F3)
        static let star = Color(hex: 0xC8D7F3)

        // Supplementary palette tokens for globe and surface layers
        static let oceanBlue = Color(hex: 0x020920)
        static let landUnvisited = Color(hex: 0x0C2457)
        static let landVisited = Color(hex: 0x2D62D3)
        static let landVisitedGlow = Color(hex: 0x5E89DD)
        static let countryBorder = Color(hex: 0x4A4A93)
        static let surfaceBorder = Color(hex: 0xC8D7F3)
    }
}

// MARK: - Hex Initializer

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}
