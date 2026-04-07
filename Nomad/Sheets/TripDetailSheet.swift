import SwiftUI

// MARK: - TripDetailSheet
//
// Secondary bottom sheet — slides up OVER ProfileSheet when a trip card is tapped.
// Nested inside ProfileSheet's body (INFRA-02 pattern) so dismissing it leaves
// ProfileSheet visible and interactive.
//
// Design: Panel gradient (D-07), Playfair Display title, Inter body (D-08).
// Copy: per UI-SPEC Copywriting Contract — city name header, "No stops recorded" empty state.

struct TripDetailSheet: View {
    let trip: GlobePinpoint.StubTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: city name per UI-SPEC Copywriting Contract
            Text(trip.cityName)
                .font(AppFont.title())  // 28pt Playfair Display Semibold
                .foregroundStyle(Color.Nomad.amber)
                .padding(.horizontal, 16)
                .padding(.top, 24)

            Text(trip.dateLabel)
                .font(AppFont.body())  // 16pt Inter Regular
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            Divider()
                .padding(.horizontal, 16)

            // Stub content — placeholder for future trip detail (Phase 2+)
            VStack(alignment: .leading, spacing: 12) {
                // Stub stats section
                HStack(spacing: 24) {
                    StatItem(label: "Steps", value: "12,450")
                    StatItem(label: "Distance", value: "8.3 km")
                    StatItem(label: "Places", value: "6")
                }

                // Empty state per UI-SPEC Copywriting Contract
                Text("No stops recorded")
                    .font(AppFont.caption())  // 13pt Inter Regular
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
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
    TripDetailSheet(trip: GlobePinpoint.StubTrip.stubTrips[0])
}
#endif
