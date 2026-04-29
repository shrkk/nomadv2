import SwiftUI

// MARK: - HomeFeedView

struct HomeFeedView: View {
    let friendPosts: [FriendTripPost]
    var onProfileTap: (() -> Void)? = nil
    var onFriendTap: ((FoundUser) -> Void)? = nil  // wired from ProfileSheet

    @State private var marqueeOffset: CGFloat = 0

    private var uniqueFriends: [FriendTripPost] {
        var seen = Set<String>()
        return friendPosts.filter { seen.insert($0.authorHandle).inserted }
    }

    // Every orb in the 9-col × 2-row grid gets an emoji.
    // isFriend=true → vivid background; false → softer background.
    // Order: col0row0, col0row1, col1row0, col1row1, ... col8row0, col8row1
    private let allOrbs: [(hue: Double, emoji: String, isFriend: Bool)] = [
        (200, "😊",   false),  // col 0, row 0
        (150, "🧑‍🦱", true),   // col 0, row 1  ★ friend
        ( 30, "😄",   false),  // col 1, row 0
        (280, "😅",   false),  // col 1, row 1
        ( 15, "👩‍🦰", true),   // col 2, row 0  ★ friend
        (340, "🥰",   false),  // col 2, row 1
        ( 45, "🤩",   false),  // col 3, row 0
        ( 35, "🧔",   true),   // col 3, row 1  ★ friend
        (260, "😍",   false),  // col 4, row 0
        ( 90, "😆",   false),  // col 4, row 1
        (270, "👩‍🦳", true),   // col 5, row 0  ★ friend
        (190, "🤗",   false),  // col 5, row 1
        (170, "😏",   false),  // col 6, row 0
        (210, "😎",   true),   // col 6, row 1  ★ friend
        (320, "👩‍🦲", true),   // col 7, row 0  ★ friend
        (230, "🧐",   false),  // col 7, row 1
        (240, "😇",   false),  // col 8, row 0
        ( 60, "🧑‍🦲", true),   // col 8, row 1  ★ friend
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                feedHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                friendOrbs
                    .padding(.bottom, 8)

                FriendTripFeed(posts: friendPosts, onAuthorTap: onFriendTap)
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
                    RadialGradient(
                        colors: [
                            Color(hue: 0.08, saturation: 0.55, brightness: 0.92),
                            Color(hue: 0.08, saturation: 0.80, brightness: 0.60)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 0,
                        endRadius: 28
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1))
                .overlay(Text("🧑").font(.system(size: 22)))

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
        let numCols = 9
        let colSpacing: CGFloat = 14
        let rowSpacing: CGFloat = 12
        let baseSize: CGFloat = 58

        // Per-orb size delta indexed by orbIdx (col*2 + row), 18 values
        let sizeDeltas: [CGFloat] = [-4, 6, -6, 4, 8, -2, 2, -8, 6, -4, 4, -6, 8, -2, -4, 6, 2, 8]

        // All-positive y-offsets per column so nothing clips at the top
        let colYOffsets: [CGFloat] = [4, 24, 0, 28, 10, 20, 26, 8, 18]

        // Tallest shifted column (col 6, bottom = 26 + 134 = 160) → frame needs > 160
        let frameHeight: CGFloat = 178
        let singleWidth = CGFloat(numCols) * (baseSize + colSpacing)

        return GeometryReader { _ in
            HStack(alignment: .top, spacing: colSpacing) {
                ForEach(0..<(numCols * 2), id: \.self) { col in
                    let colIdx = col % numCols
                    VStack(spacing: rowSpacing) {
                        ForEach(0..<2, id: \.self) { row in
                            let orbIdx = colIdx * 2 + row
                            let def = allOrbs[orbIdx]
                            let size = baseSize + sizeDeltas[orbIdx]
                            orbCircle(hue: def.hue, size: size, emoji: def.emoji, isFriend: def.isFriend)
                        }
                    }
                    .offset(y: colYOffsets[colIdx])
                }
            }
            .offset(x: marqueeOffset)
            .onAppear {
                marqueeOffset = 0
                withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
                    marqueeOffset = -singleWidth
                }
            }
        }
        .frame(height: frameHeight)
        // Fade edges horizontally instead of hard-clipping
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear,  location: 0.00),
                    .init(color: .black,  location: 0.07),
                    .init(color: .black,  location: 0.93),
                    .init(color: .clear,  location: 1.00),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private func orbCircle(hue: Double, size: CGFloat, emoji: String, isFriend: Bool) -> some View {
        let h = hue / 360.0
        let satTop: Double    = isFriend ? 0.60 : 0.38
        let satBottom: Double = isFriend ? 0.82 : 0.58
        let briTop: Double    = isFriend ? 0.92 : 0.74
        let briBottom: Double = isFriend ? 0.65 : 0.48
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hue: h, saturation: satTop,    brightness: briTop),
                        Color(hue: h, saturation: satBottom, brightness: briBottom)
                    ],
                    center: UnitPoint(x: 0.35, y: 0.30),
                    startRadius: 0,
                    endRadius: size * 0.7
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(emoji)
                    .font(.system(size: size * 0.58))
            )
            .shadow(
                color: Color(hue: h, saturation: 0.7, brightness: 0.8).opacity(isFriend ? 0.50 : 0.25),
                radius: 7, x: -2, y: -3
            )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let posts = [
        FriendTripPost(
            id: "1", authorUID: "mock-uid-maya", authorHandle: "maya.v", authorAvatarHue: 260,
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
            id: "2", authorUID: "mock-uid-leo", authorHandle: "leo.b", authorAvatarHue: 20,
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
