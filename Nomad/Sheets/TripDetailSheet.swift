import SwiftUI

// MARK: - TripDetailSheet
//
// Secondary bottom sheet — slides up OVER CountryDetailSheet (and ProfileSheet) when
// a trip card is tapped. Nested via INFRA-02 pattern so dismissing leaves parent visible.
//
// Design: Panel gradient (D-07), Playfair Display title, Inter body (D-08).
// Copy: per UI-SPEC Copywriting Contract — city name header, "No stops recorded" empty state.
//
// [Rule 1 - Bug] Updated to accept TripDocument instead of GlobePinpoint.StubTrip —
// the stub type was Phase 1 placeholder; CountryDetailSheet passes real TripDocument models.

struct TripDetailSheet: View {
    let trip: TripDocument

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: trip.startDate)
    }

    private var distanceKm: String {
        String(format: "%.1f km", trip.distanceMeters / 1000)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: city name per UI-SPEC Copywriting Contract
            Text(trip.cityName)
                .font(AppFont.title())  // 28pt Playfair Display Semibold
                .foregroundStyle(Color.Nomad.amber)
                .padding(.horizontal, 16)
                .padding(.top, 24)

            Text(formattedDate)
                .font(AppFont.body())  // 16pt Inter Regular
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            Divider()
                .padding(.horizontal, 16)

            // Stats section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 24) {
                    StatItem(label: "Steps", value: "\(trip.stepCount)")
                    StatItem(label: "Distance", value: distanceKm)
                    StatItem(label: "Places", value: "\(trip.placeCounts.values.reduce(0, +))")
                }

                if trip.routePreview.isEmpty {
                    // Empty state per UI-SPEC Copywriting Contract
                    Text("No stops recorded")
                        .font(AppFont.caption())  // 13pt Inter Regular
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelGradient()  // Same gradient treatment as ProfileSheet per D-07
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Stat Display Component

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.subheading())  // 20pt Playfair Display Regular
                .foregroundStyle(Color.Nomad.amber)
            Text(label)
                .font(AppFont.caption())  // 13pt Inter Regular
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
#Preview {
    let sampleTrip = TripDocument(
        id: "trip-preview",
        cityName: "Vienna",
        startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
        endDate: Calendar.current.date(byAdding: .day, value: -8, to: Date()) ?? Date(),
        stepCount: 12450,
        distanceMeters: 8300,
        routePreview: [[48.2082, 16.3738], [48.2150, 16.3800]],
        visitedCountryCodes: ["AT"],
        placeCounts: ["culture": 3, "food": 2, "nature": 1]
    )
    TripDetailSheet(trip: sampleTrip)
}
#endif
