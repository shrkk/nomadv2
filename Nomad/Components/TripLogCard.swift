import SwiftUI

// MARK: - TripLogCard
//
// Card showing a single trip log entry: route strip preview + trip name + date.
// Tap opens TripDetailSheet via onTap callback (INFRA-02 nested sheet pattern).
// Per UI-SPEC Trip Log Card spec: warmCard background, 12pt corner radius, 12pt padding.

struct TripLogCard: View {
    let trip: TripDocument
    let onTap: () -> Void

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: trip.startDate)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Route strip: 48x36pt
                routeStrip

                // Text block
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.cityName)
                        .font(AppFont.body())
                        .foregroundStyle(Color.Nomad.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(formattedDate)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.Nomad.textSecondary)
                }

                Spacer()
            }
            .padding(12)
            .innerCardSurface()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Route Strip

    private var routeStrip: some View {
        GeometryReader { geo in
            ZStack {
                Color.Nomad.panelBlack

                if trip.routePreview.count >= 2 {
                    RoutePreviewPath(routePreview: trip.routePreview, size: geo.size)
                        .padding(4)
                } else {
                    Image(systemName: "mappin.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Nomad.accent)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(width: 48, height: 36)
    }
}

#if DEBUG
#Preview {
    let sampleTrip = TripDocument(
        id: "trip-1",
        cityName: "Vienna",
        startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
        endDate: Calendar.current.date(byAdding: .day, value: -8, to: Date()) ?? Date(),
        stepCount: 18000,
        distanceMeters: 12000,
        routePreview: [
            [48.2082, 16.3738],
            [48.2150, 16.3800],
            [48.2200, 16.3900]
        ],
        visitedCountryCodes: ["AT"],
        placeCounts: ["culture": 3, "food": 2]
    )
    VStack(spacing: 8) {
        TripLogCard(trip: sampleTrip, onTap: {})
    }
    .padding()
    .background(Color.Nomad.panelBlack)
}
#endif
