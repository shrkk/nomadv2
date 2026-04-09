import SwiftUI

// MARK: - CityThumbnailCard
//
// Single city thumbnail card for the horizontal strip in CountryDetailSheet.
// Displays a 64x80pt photo or placeholder, city name label, and amber selection indicator.
// Per UI-SPEC City Thumbnail Card spec.

struct CityThumbnailCard: View {
    let cityName: String
    let photo: UIImage?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            // Image area: 64x80pt
            imageArea

            // City name label
            Text(cityName)
                .font(AppFont.caption())
                .foregroundStyle(Color.Nomad.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 64)

            // Selection dot — white when selected, clear spacer when not
            if isSelected {
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
            } else {
                Color.clear
                    .frame(width: 4, height: 4)
            }
        }
        .frame(width: 64)
        .contentShape(Rectangle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelected)
    }

    // MARK: - Image Area

    @ViewBuilder
    private var imageArea: some View {
        Group {
            if let photo = photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.Nomad.panelBlack)
                    .frame(width: 64, height: 80)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? Color.white : Color.white.opacity(0.15),
                    lineWidth: isSelected ? 2 : 1
                )
        }
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 8) {
        CityThumbnailCard(cityName: "Vienna", photo: nil, isSelected: true)
        CityThumbnailCard(cityName: "Salzburg", photo: nil, isSelected: false)
        CityThumbnailCard(cityName: "Innsbruck", photo: nil, isSelected: false)
    }
    .padding()
    .background(Color.Nomad.panelBlack)
}
#endif
