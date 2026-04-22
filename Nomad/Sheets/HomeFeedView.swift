import SwiftUI

// MARK: - HomeFeedView
//
// Home tab of the bottom drawer. Shows the "nomad" wordmark, scattered
// friend-avatar orbs, and the recent-trips feed — matching the design spec.

struct HomeFeedView: View {
    let friendPosts: [FriendTripPost]
    var onProfileTap: (() -> Void)? = nil

    @State private var marqueeOffset: CGFloat = 0

    private var uniqueFriends: [FriendTripPost] {
        var seen = Set<String>()
        return friendPosts.filter { seen.insert($0.authorHandle).inserted }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                feedHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                if !uniqueFriends.isEmpty {
                    friendOrbs
                        .padding(.bottom, 8)
                }

                FriendTripFeed(posts: friendPosts)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Header

    private var feedHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("nomad")
                .font(.custom("CalSans-Regular", size: 30))
                .foregroundStyle(Color.Nomad.textPrimary)

            Spacer()

            addFriendButton
        }
    }

    private var addFriendButton: some View {
        Button { onProfileTap?() } label: { profileOrbContent }
            .buttonStyle(.plain)
    }

    private var profileOrbContent: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.08, saturation: 0.45, brightness: 0.72),
                            Color(hue: 0.08, saturation: 0.38, brightness: 0.42)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))

            Circle()
                .fill(Color.Nomad.accent)
                .frame(width: 18, height: 18)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.Nomad.panelBlack)
                )
                .offset(x: 4, y: 4)
        }
    }

    // MARK: - Friend Orbs (horizontal marquee)

    private var friendOrbs: some View {
        let orbSize: CGFloat = 52
        let colSpacing: CGFloat = 10
        let rowSpacing: CGFloat = 6
        let numCols = 12
        let colWidth = orbSize + colSpacing
        let singleWidth = CGFloat(numCols) * colWidth
        // Hues cycle through friends then placeholder palette
        let friendHues = uniqueFriends.map { $0.authorAvatarHue }
        let fallbackHues: [Double] = [210, 30, 150, 270, 60, 330, 90, 180, 0, 240, 120, 300]
        let allHues: [Double] = friendHues + fallbackHues

        return GeometryReader { _ in
            HStack(alignment: .top, spacing: colSpacing) {
                // Two copies for seamless infinite loop
                ForEach(0..<(numCols * 2), id: \.self) { col in
                    let colIdx = col % numCols
                    VStack(spacing: rowSpacing) {
                        ForEach(0..<3, id: \.self) { row in
                            let hueIdx = (colIdx * 3 + row) % allHues.count
                            let isFriend = (colIdx * 3 + row) < friendHues.count
                            orbCircle(
                                hue: allHues[hueIdx],
                                size: orbSize,
                                saturated: isFriend
                            )
                        }
                    }
                    .offset(y: colIdx.isMultiple(of: 2) ? 0 : orbSize * 0.5 + rowSpacing * 0.5)
                }
            }
            .offset(x: marqueeOffset)
            .onAppear {
                marqueeOffset = 0
                withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                    marqueeOffset = -singleWidth
                }
            }
        }
        .frame(height: orbSize * 3 + rowSpacing * 2 + orbSize * 0.5 + 4)
        .clipped()
    }

    private func orbCircle(hue: Double, size: CGFloat, saturated: Bool = true) -> some View {
        let h = hue / 360.0
        let sat: (Double, Double) = saturated ? (0.32, 0.52) : (0.20, 0.38)
        let bri: (Double, Double) = saturated ? (0.82, 0.40) : (0.62, 0.30)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hue: h, saturation: sat.0, brightness: bri.0),
                        Color(hue: h, saturation: sat.1, brightness: bri.1)
                    ],
                    center: UnitPoint(x: 0.35, y: 0.30),
                    startRadius: 0,
                    endRadius: size * 0.7
                )
            )
            .frame(width: size, height: size)
            .shadow(color: Color(hue: h, saturation: 0.5, brightness: 0.6).opacity(saturated ? 0.45 : 0.25), radius: 6, x: -2, y: -3)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let posts = [
        FriendTripPost(
            id: "1", authorHandle: "maya.v", authorAvatarHue: 260,
            trip: TripDocument(
                id: "t1", cityName: "walk to denny",
                startDate: Date(timeIntervalSinceNow: -86_400 * 3),
                endDate: Date(timeIntervalSinceNow: -86_400 * 3 + 7_200),
                stepCount: 8_200, distanceMeters: 5_400,
                routePreview: [[47.6205, -122.3493], [47.6150, -122.3400], [47.6062, -122.3321]],
                visitedCountryCodes: ["US"], placeCounts: [:]
            )
        ),
        FriendTripPost(
            id: "2", authorHandle: "leo.b", authorAvatarHue: 20,
            trip: TripDocument(
                id: "t2", cityName: "ferry loop",
                startDate: Date(timeIntervalSinceNow: -86_400 * 7),
                endDate: Date(timeIntervalSinceNow: -86_400 * 7 + 5_400),
                stepCount: 6_100, distanceMeters: 4_200,
                routePreview: [[47.6020, -122.3380], [47.6130, -122.3590]],
                visitedCountryCodes: ["US"], placeCounts: [:]
            )
        )
    ]
    ScrollView {
        HomeFeedView(friendPosts: posts)
    }
    .background(Color.Nomad.panelBlack.ignoresSafeArea())
}
#endif
