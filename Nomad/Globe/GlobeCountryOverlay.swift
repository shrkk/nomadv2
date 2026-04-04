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
        size: CGSize = CGSize(width: 4096, height: 2048)
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // Transparent background — only visited countries are painted
            cgCtx.clear(CGRect(origin: .zero, size: size))

            // Fill color: #E8A44A at 60% opacity per D-03
            let fillColor = UIColor(red: 0.910, green: 0.643, blue: 0.290, alpha: 0.6)
            // Glow color: #E8A44A at 30% opacity per D-03 (2-3px outer glow)
            let glowColor = UIColor(red: 0.910, green: 0.643, blue: 0.290, alpha: 0.3)

            // Filter to only visited countries
            let visitedCountries = countries.filter { visitedCodes.contains($0.isoCode) }

            for country in visitedCountries {
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

                    // Apply outer glow via CGContext shadow (renders before fill)
                    // Shadow with zero offset creates an even outer glow per D-03
                    cgCtx.setShadow(
                        offset: .zero,
                        blur: 8,
                        color: glowColor.cgColor
                    )

                    cgCtx.setFillColor(fillColor.cgColor)
                    cgCtx.addPath(path)
                    cgCtx.fillPath()

                    // Reset shadow so subsequent polygons don't accumulate glow
                    cgCtx.setShadow(offset: .zero, blur: 0, color: UIColor.clear.cgColor)
                }
            }
        }

        return image
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
        return try TextureResource(image: cgImage, options: .init(semantic: .color))
    }
}
