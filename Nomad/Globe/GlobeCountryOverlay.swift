import UIKit
import CoreLocation
import RealityKit

// MARK: - GlobeCountryOverlay

/// Renders visited country polygons onto an equirectangular UIImage texture for
/// application to the RealityKit globe sphere surface.
///
/// Design spec: D-03 (CONTEXT.md)
/// - Visited countries: #E8A44A at 60% opacity
/// - Outer glow: 2-3px bleed, #E8A44A at ~30% opacity (via CGContext shadow)
/// - Texture size: 4096x2048 (equirectangular projection, width=360°, height=180°)
struct GlobeCountryOverlay {

    // MARK: - Hardcoded visited countries for Phase 1 spike
    // Five countries that do NOT cross the anti-meridian.
    // Source: 01-03-PLAN.md Task 1 specification.
    static let hardcodedVisitedCodes: Set<String> = ["JP", "FR", "KE", "AU", "BR"]

    // MARK: - Coordinate Conversion

    /// Converts geographic coordinates to pixel coordinates in equirectangular projection.
    /// - Parameters:
    ///   - lon: Longitude in degrees (-180...180)
    ///   - lat: Latitude in degrees (-90...90)
    ///   - size: Canvas size in pixels (width=360°, height=180°)
    /// - Returns: Pixel position on the equirectangular canvas
    static func geoJSONToPixel(lon: Double, lat: Double, size: CGSize) -> CGPoint {
        let x = ((lon + 180.0) / 360.0) * size.width   // 0...width, left to right
        let y = ((90.0 - lat) / 180.0) * size.height   // 0...height, top to bottom (Y-flipped)
        return CGPoint(x: x, y: y)
    }

    // MARK: - Texture Rendering

    /// Renders visited country polygons onto an equirectangular UIImage.
    ///
    /// The resulting image has a transparent background — only visited country
    /// polygons are drawn, enabling blending over the base globe material.
    ///
    /// - Parameters:
    ///   - countries: All parsed country features from GeoJSON
    ///   - visitedCodes: ISO_A2 codes of visited countries to highlight
    ///   - size: Texture size (default 4096x2048 for full sphere coverage)
    /// - Returns: UIImage with filled country polygons on transparent background
    static func renderOverlayTexture(
        countries: [CountryFeature],
        visitedCodes: Set<String> = hardcodedVisitedCodes,
        size: CGSize = CGSize(width: 2048, height: 1024)
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // Ocean background — deepest navy (#020920)
            let oceanColor = UIColor(hex: 0x020920)
            cgCtx.setFillColor(oceanColor.cgColor)
            cgCtx.fill(CGRect(origin: .zero, size: size))

            // Land color for unvisited countries — dark navy (#0C2457)
            let landColor = UIColor(hex: 0x0C2457)
            // Visited country fill — medium blue (#2D62D3) at 80% opacity
            let visitedFillColor = UIColor(hex: 0x2D62D3, alpha: 0.8)
            // Visited glow — periwinkle blue (#5E89DD) at 50% opacity
            let glowColor = UIColor(hex: 0x5E89DD, alpha: 0.5)
            // Border for all countries — muted indigo (#4A4A93) at 60% opacity
            let borderColor = UIColor(hex: 0x4A4A93, alpha: 0.6)

            // Draw ALL countries as land masses first
            for country in countries {
                let isVisited = visitedCodes.contains(country.isoCode)

                for ring in country.polygons {
                    guard ring.count >= 3 else { continue }

                    let path = CGMutablePath()
                    let firstPoint = geoJSONToPixel(
                        lon: ring[0].longitude,
                        lat: ring[0].latitude,
                        size: size
                    )
                    path.move(to: firstPoint)

                    for coord in ring.dropFirst() {
                        let point = geoJSONToPixel(
                            lon: coord.longitude,
                            lat: coord.latitude,
                            size: size
                        )
                        path.addLine(to: point)
                    }
                    path.closeSubpath()

                    if isVisited {
                        // Visited: amber glow + fill
                        cgCtx.setShadow(offset: .zero, blur: 8, color: glowColor.cgColor)
                        cgCtx.setFillColor(visitedFillColor.cgColor)
                    } else {
                        // Unvisited: flat land color, no glow
                        cgCtx.setShadow(offset: .zero, blur: 0, color: UIColor.clear.cgColor)
                        cgCtx.setFillColor(landColor.cgColor)
                    }

                    cgCtx.addPath(path)
                    cgCtx.fillPath()

                    // Subtle border on all countries
                    cgCtx.setShadow(offset: .zero, blur: 0, color: UIColor.clear.cgColor)
                    cgCtx.setStrokeColor(borderColor.cgColor)
                    cgCtx.setLineWidth(1.0)
                    cgCtx.addPath(path)
                    cgCtx.strokePath()
                }
            }
        }

        return image
    }

    // MARK: - Passport Flat Map

    /// Renders a flat 2D equirectangular world map for the passport view.
    /// Visited countries are highlighted in gold; unvisited in dark navy.
    static func renderPassportMap(
        countries: [CountryFeature],
        visitedCodes: Set<String>,
        size: CGSize = CGSize(width: 800, height: 400)
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let gc = ctx.cgContext

            // Ocean — deep navy
            gc.setFillColor(UIColor(hex: 0x0F0F28).cgColor)
            gc.fill(CGRect(origin: .zero, size: size))

            let landColor = UIColor(hex: 0x1C4396, alpha: 0.35)
            let visitedFill = UIColor(hex: 0x5EE0DD, alpha: 0.9)   // light neon blue
            let visitedGlow = UIColor(hex: 0x5EE0DD, alpha: 0.4)
            let borderColor = UIColor(hex: 0x4A4A93, alpha: 0.3)

            for country in countries {
                let isVisited = visitedCodes.contains(country.isoCode)

                for ring in country.polygons {
                    guard ring.count >= 3 else { continue }

                    let path = CGMutablePath()
                    let first = geoJSONToPixel(lon: ring[0].longitude, lat: ring[0].latitude, size: size)
                    path.move(to: first)
                    for coord in ring.dropFirst() {
                        path.addLine(to: geoJSONToPixel(lon: coord.longitude, lat: coord.latitude, size: size))
                    }
                    path.closeSubpath()

                    if isVisited {
                        gc.setShadow(offset: .zero, blur: 6, color: visitedGlow.cgColor)
                        gc.setFillColor(visitedFill.cgColor)
                    } else {
                        gc.setShadow(offset: .zero, blur: 0, color: UIColor.clear.cgColor)
                        gc.setFillColor(landColor.cgColor)
                    }
                    gc.addPath(path)
                    gc.fillPath()

                    gc.setShadow(offset: .zero, blur: 0, color: UIColor.clear.cgColor)
                    gc.setStrokeColor(borderColor.cgColor)
                    gc.setLineWidth(0.5)
                    gc.addPath(path)
                    gc.strokePath()
                }
            }
        }
    }

    // MARK: - TextureResource Conversion

    /// Converts an overlay UIImage to a RealityKit TextureResource for sphere material use.
    ///
    /// - Parameter image: Rendered overlay image (transparent background + country polygons)
    /// - Returns: TextureResource ready for use in UnlitMaterial
    /// - Throws: GlobeError.parseError if CGImage conversion fails, or TextureResource error
    @MainActor
    static func makeTextureResource(from image: UIImage) throws -> TextureResource {
        guard let cgImage = image.cgImage else {
            throw GlobeError.parseError("Failed to get CGImage from overlay UIImage")
        }
        // Use default options — .init(semantic:) causes createFailure on simulator
        return try TextureResource(image: cgImage, options: .init(semantic: nil))
    }
}
