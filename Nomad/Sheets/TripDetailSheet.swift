import SwiftUI

// MARK: - TripDetailSheet
//
// Secondary bottom sheet — slides up OVER ProfileSheet when a trip card is tapped.
// Nested inside ProfileSheet's body (INFRA-02 pattern) so dismissing it leaves
// ProfileSheet visible and interactive.
//
// Design: Panel gradient (D-07), Playfair Display title, Inter body (D-08).
// Copy: per UI-SPEC Copywriting Contract — city name header, "No stops recorded" empty state.
// Updated in Phase 3 Plan 01: accepts TripDocument instead of StubTrip.

struct TripDetailSheet: View {
    let trip: TripDocument

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: city name per UI-SPEC Copywriting Contract
            Text(trip.cityName)
                .font(AppFont.title())  // 28pt Playfair Display Semibold
                .foregroundStyle(Color.Nomad.amber)
                .padding(.horizontal, 16)
                .padding(.top, 24)

            Text(Self.dateFormatter.string(from: trip.startDate))
                .font(AppFont.body())  // 16pt Inter Regular
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            Divider()
                .padding(.horizontal, 16)

            // Stub stats layout — Plan 04 replaces with real data
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 24) {
                    StatItem(label: "Steps", value: formatSteps(trip.stepCount))
                    StatItem(label: "Distance", value: formatDistance(trip.distanceMeters))
                    StatItem(label: "Places", value: "\(trip.placeCounts.values.reduce(0, +))")
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

    private func formatSteps(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    private func formatDistance(_ meters: Double) -> String {
        let km = meters / 1000
        return String(format: "%.1f km", km)
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
private let previewTrip = TripDocument(
    id: "preview-tokyo",
    cityName: "Tokyo",
    startDate: Date(timeIntervalSinceNow: -86400 * 30),
    endDate: Date(timeIntervalSinceNow: -86400 * 28),
    stepCount: 12450,
    distanceMeters: 8300,
    routePreview: [[35.6762, 139.6503]],
    visitedCountryCodes: ["JP"],
    placeCounts: ["food": 3, "culture": 2]
)

#Preview {
    TripDetailSheet(trip: previewTrip)
}
#endif
