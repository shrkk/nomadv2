import SwiftUI
import CoreLocation

// MARK: - FriendGlobeView
//
// Read-only globe showing a friend's trips and home city pin.
// Pin taps zoom to the city and open TripDetailSheet for that trip.

@MainActor
struct FriendGlobeView: View {
    let friend: FoundUser
    let trips: [TripDocument]
    var homeCityName: String? = nil
    var homeCityCoordinate: CLLocationCoordinate2D? = nil

    @State private var viewModel = GlobeViewModel()
    @State private var showTripDetail = false
    @State private var selectedTrip: TripDocument? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.Nomad.globeBackground.ignoresSafeArea()

            GlobeMapView(
                viewModel: viewModel,
                onTapCountry: { _ in },
                homeCityCoordinate: homeCityCoordinate,
                homeCityName: homeCityName,
                tripPhotos: [:],
                activeRouteCoordinates: viewModel.activeRouteCoordinates
            )
            .ignoresSafeArea()

            // Top bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.Nomad.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Spacer()

                Text("@\(friend.handle)'s Globe")
                    .font(.custom("CalSans-Regular", size: 16))
                    .foregroundStyle(Color.Nomad.textPrimary)

                Spacer()

                // Invisible spacer to balance the dismiss button
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .task {
            // Load GeoJSON countries for globe rendering
            if viewModel.countries.isEmpty {
                if let loaded = try? await GeoJSONParser().loadCountries() {
                    viewModel.countries = loaded
                }
            }
            // Populate with friend's trips instead of the current user's
            viewModel.trips = trips
        }
        .onChange(of: viewModel.showCountryDetail) { _, show in
            guard show else { return }
            viewModel.showCountryDetail = false
            // Find the trip that was tapped by matching city name
            if let cityName = viewModel.selectedInitialCity,
               let trip = trips.first(where: { $0.cityName == cityName }) {
                selectedTrip = trip
                showTripDetail = true
            }
        }
        .sheet(isPresented: $showTripDetail) {
            if let trip = selectedTrip {
                TripDetailSheet(trip: trip, ownerUID: friend.uid)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    FriendGlobeView(
        friend: FoundUser(uid: "mock-uid-maya", handle: "maya.v", avatarHue: 260),
        trips: [
            TripDocument(
                id: "mock-t1", cityName: "Kyoto",
                startDate: Date(timeIntervalSinceNow: -86_400 * 2),
                endDate: Date(timeIntervalSinceNow: -86_400 * 2 + 10_800),
                stepCount: 11_400, distanceMeters: 7_800,
                routePreview: [[35.0116, 135.7681], [35.0194, 135.7723]],
                visitedCountryCodes: ["JP"], placeCounts: ["culture": 4, "food": 2]
            )
        ]
    )
}
#endif
