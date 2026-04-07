import SwiftUI
import UIKit

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
                .foregroundStyle(Color.Nomad.globeBackground)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 64)

            // Selection dot — amber when selected, clear spacer when not
            if isSelected {
                Circle()
                    .fill(Color.Nomad.amber)
                    .frame(width: 4, height: 4)
            } else {
                Color.clear
                    .frame(width: 4, height: 4)
            }
        }
        .frame(width: 64)
        .contentShape(Rectangle())
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
                    .fill(Color.Nomad.warmCard)
                    .frame(width: 64, height: 80)
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.Nomad.amber, lineWidth: 2)
            }
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
    .background(Color.Nomad.cream)
}
#endif
