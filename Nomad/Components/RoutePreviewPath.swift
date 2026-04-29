import SwiftUI

// MARK: - RoutePreviewPath
//
// Draws a SwiftUI Path from routePreview [[lat, lon]] coordinate array.
// Normalizes coordinates to fit within the given size, flipping Y-axis
// (lat increases upward, SwiftUI origin is top-left).
//
// Usage: 120×48pt per UI-SPEC Trip Preview Card. Amber stroke, 1.5pt lineWidth.
// Source: D-03, D-04, UI-SPEC Trip Preview Card.

struct RoutePreviewPath: View {
    let routePreview: [[Double]]
    let size: CGSize
    var strokeColor: Color = Color.Nomad.textPrimary
    var lineWidth: CGFloat = 1.5

    var body: some View {
        routePath(from: routePreview, in: size)
            .stroke(strokeColor, lineWidth: lineWidth)
    }

    private func routePath(from preview: [[Double]], in size: CGSize) -> Path {
        guard preview.count >= 2 else { return Path() }

        let lons = preview.map { $0.count >= 2 ? $0[1] : 0 }
        let lats = preview.map { $0[0] }

        guard let minLon = lons.min(), let maxLon = lons.max(),
              let minLat = lats.min(), let maxLat = lats.max() else { return Path() }

        let lonRange = max(maxLon - minLon, 0.0001) // avoid division by zero
        let latRange = max(maxLat - minLat, 0.0001)

        func point(for pair: [Double]) -> CGPoint {
            guard pair.count >= 2 else { return .zero }
            let x = CGFloat((pair[1] - minLon) / lonRange) * size.width
            // Flip Y: lat increases up, SwiftUI origin is top-left
            let y = CGFloat(1.0 - (pair[0] - minLat) / latRange) * size.height
            return CGPoint(x: x, y: y)
        }

        var path = Path()
        path.move(to: point(for: preview[0]))
        for pair in preview.dropFirst() {
            path.addLine(to: point(for: pair))
        }
        return path
    }
}

#if DEBUG
#Preview {
    let sampleRoute: [[Double]] = [
        [35.6762, 139.6503],
        [35.6895, 139.6917],
        [35.7100, 139.8107],
        [35.6584, 139.7454],
        [35.6328, 139.8802]
    ]
    let size = CGSize(width: 120, height: 48)

    ZStack {
        Color.Nomad.globeBackground
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        RoutePreviewPath(routePreview: sampleRoute, size: size)
            .frame(width: size.width, height: size.height)
    }
    .padding()
    .background(Color.Nomad.panelBlack)
}
#endif
