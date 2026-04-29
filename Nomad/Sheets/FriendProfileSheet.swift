import SwiftUI
import CoreLocation

// MARK: - FriendProfileSheet
//
// Full-screen sheet showing a friend's passport card, trip log, and globe access.
// Triggered by tapping a friend's avatar in the home feed.

struct FriendProfileSheet: View {
    let friend: FoundUser
    var seedTrips: [TripDocument] = []  // trips already known from the feed; shown immediately

    @State private var trips: [TripDocument] = []
    @State private var homeCityName: String? = nil
    @State private var homeCityCoordinate: CLLocationCoordinate2D? = nil
    @State private var isLoading = true
    @State private var showPassport = false
    @State private var showGlobe = false
    @State private var showTripDetail = false
    @State private var selectedTrip: TripDocument? = nil

    @Environment(\.dismiss) private var dismiss

    private var visitedCountryCodes: [String] {
        Array(Set(trips.flatMap(\.visitedCountryCodes)))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                statsRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                actionButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                tripSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.Nomad.panelBlack, Color(hex: 0x0A0A1E)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.Nomad.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.Nomad.surfaceBorder.opacity(0.15))
                    .clipShape(Circle())
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $showPassport) {
            TravelerPassport(
                trips: trips,
                visitedCountryCodes: visitedCountryCodes,
                homeCityName: homeCityName,
                externalHandle: friend.handle,
                externalUID: friend.uid
            )
        }
        .sheet(isPresented: $showGlobe) {
            FriendGlobeView(
                friend: friend,
                trips: trips,
                homeCityName: homeCityName,
                homeCityCoordinate: homeCityCoordinate
            )
        }
        .sheet(isPresented: $showTripDetail) {
            if let trip = selectedTrip {
                TripDetailSheet(trip: trip, ownerUID: friend.uid)
            }
        }
        .task { await loadFriendData() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            friendAvatar(size: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text("@\(friend.handle)")
                    .font(.custom("CalSans-Regular", size: 22))
                    .foregroundStyle(Color.Nomad.textPrimary)
                Text("\(visitedCountryCodes.count) countries · \(trips.count) trips")
                    .font(.custom("Inter-Regular", size: 13))
                    .foregroundStyle(Color.Nomad.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    private func friendAvatar(size: CGFloat) -> some View {
        let h = friend.avatarHue / 360.0
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hue: h, saturation: 0.55, brightness: 0.88),
                        Color(hue: h, saturation: 0.78, brightness: 0.55)
                    ],
                    center: UnitPoint(x: 0.35, y: 0.30),
                    startRadius: 0,
                    endRadius: size * 0.7
                )
            )
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1.5))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: "\(trips.count)", label: "Trips")
            statDivider
            statCell(value: "\(visitedCountryCodes.count)", label: "Countries")
            statDivider
            statCell(value: "\(Set(trips.map(\.locality)).count)", label: "Cities")
            statDivider
            statCell(value: totalDistanceLabel, label: "Distance")
        }
        .padding(.vertical, 14)
        .innerCardSurface()
    }

    private var totalDistanceLabel: String {
        let km = trips.reduce(0.0) { $0 + $1.distanceMeters } / 1000.0
        if km >= 1000 { return String(format: "%.1fk", km / 1000) }
        return String(format: "%.0f km", km)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("CalSans-Regular", size: 20))
                .foregroundStyle(Color.Nomad.accent)
            Text(label)
                .font(.custom("Inter-Regular", size: 11))
                .tracking(0.5)
                .foregroundStyle(Color.Nomad.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.Nomad.surfaceBorder.opacity(0.15))
            .frame(width: 1, height: 32)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { showPassport = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 14, weight: .medium))
                    Text("Passport")
                        .font(.custom("CalSans-Regular", size: 15))
                }
                .foregroundStyle(Color.Nomad.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.Nomad.globeBackground.opacity(0.50))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.Nomad.surfaceBorder.opacity(0.18), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button { showGlobe = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .medium))
                    Text("Globe")
                        .font(.custom("CalSans-Regular", size: 15))
                }
                .foregroundStyle(Color.Nomad.panelBlack)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.Nomad.accent)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Trip Section

    private var tripSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("JOURNEYS")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.Nomad.textSecondary)
                    .tracking(1.5)
                Spacer()
            }

            if isLoading {
                ProgressView()
                    .tint(Color.Nomad.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if trips.isEmpty {
                Text("No trips yet.")
                    .font(.custom("CalSans-Regular", size: 14))
                    .foregroundStyle(Color.Nomad.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                VStack(spacing: 8) {
                    ForEach(trips) { trip in
                        friendTripRow(trip)
                    }
                }
            }
        }
    }

    private func friendTripRow(_ trip: TripDocument) -> some View {
        Button {
            selectedTrip = trip
            showTripDetail = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    GeometryReader { geo in
                        RoutePreviewPath(routePreview: trip.routePreview, size: geo.size)
                    }
                }
                .frame(width: 52, height: 38)
                .background(Color.Nomad.globeBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.cityName)
                        .font(.custom("Inter-SemiBold", size: 14))
                        .foregroundStyle(Color.Nomad.textPrimary)
                        .lineLimit(1)
                    Text(Self.dateFormatter.string(from: trip.startDate))
                        .font(.custom("Inter-Regular", size: 11))
                        .foregroundStyle(Color.Nomad.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.Nomad.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: 0x020920).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.Nomad.surfaceBorder.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data Loading

    private func loadFriendData() async {
        // Show seed trips immediately so the sheet isn't blank
        if trips.isEmpty { trips = seedTrips }

        let tripService = TripService()
        let userService = UserService()

        if let fetched = try? await tripService.fetchTrips(userId: friend.uid), !fetched.isEmpty {
            trips = fetched  // real data replaces seed data
        }

        if let userData = try? await userService.fetchUserDocument(uid: friend.uid) {
            homeCityName = userData[FirestoreSchema.UserFields.homeCityName] as? String
            if let lat = userData[FirestoreSchema.UserFields.homeCityLatitude] as? Double,
               let lon = userData[FirestoreSchema.UserFields.homeCityLongitude] as? Double,
               lat != 0 || lon != 0 {
                homeCityCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }

        isLoading = false
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    Color.Nomad.globeBackground.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            FriendProfileSheet(friend: FoundUser(uid: "mock-uid-maya", handle: "maya.v", avatarHue: 260))
        }
}
#endif
