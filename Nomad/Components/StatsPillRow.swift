import SwiftUI

// MARK: - StatsPillRow
//
// Three-stat horizontal pill showing logs count, distance in km, and photo count.
// Per UI-SPEC Stats Pill spec: amber values, 44pt height, warmCard background.

struct StatsPillRow: View {
    let tripCount: Int
    let distanceKm: Double
    let photoCount: Int

    var body: some View {
        HStack(spacing: 0) {
            statCell(value: "\(tripCount)", label: "logs")

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 20)

            statCell(value: String(format: "%.1f", distanceKm), label: "km")

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 20)

            statCell(value: "\(photoCount)", label: "photos")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.body())
                .foregroundStyle(Color.Nomad.accent)

            Text(label)
                .font(AppFont.caption())
                .foregroundStyle(Color.Nomad.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        StatsPillRow(tripCount: 26, distanceKm: 112.5, photoCount: 84)
        StatsPillRow(tripCount: 0, distanceKm: 0, photoCount: 0)
    }
    .padding()
    .background(Color.Nomad.panelBlack)
}
#endif
