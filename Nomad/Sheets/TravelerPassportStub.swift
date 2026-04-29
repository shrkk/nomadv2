import SwiftUI
@preconcurrency import FirebaseAuth

// MARK: - TravelerPassport
//
// Holographic trading-card-style passport. Tilt to reveal the holo shine.
// Based on the Nomad Passport "Trading Card" concept design.

struct TravelerPassport: View {
    let trips: [TripDocument]
    let visitedCountryCodes: [String]
    var countries: [CountryFeature] = []
    var homeCityName: String? = nil
    var friendPosts: [FriendTripPost] = []
    var onTripTap: ((TripDocument) -> Void)? = nil
    var onDeleteTrip: ((TripDocument) -> Void)? = nil
    var onStartTrip: (() -> Void)? = nil

    // Friend mode: when set, shows another user's passport (read-only, no share/AddFriend)
    var externalHandle: String? = nil
    var externalUID: String? = nil

    @State private var tilt: CGSize = .zero
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    // MARK: - Stats

    private var totalTrips: Int { trips.count }
    private var totalCountries: Int { Set(visitedCountryCodes).count }
    private var totalCities: Int { Set(trips.map(\.locality)).count }
    private var totalDistanceKm: Double { trips.reduce(0) { $0 + $1.distanceMeters } / 1000.0 }
    private var totalSteps: Int { trips.reduce(0) { $0 + $1.stepCount } }
    private var totalContinents: Int {
        Set(Set(visitedCountryCodes).compactMap(Self.continent(for:))).count
    }

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    private var isFriendMode: Bool { externalHandle != nil }

    private var displayName: String {
        if let h = externalHandle {
            return h.split(separator: ".").map { $0.capitalized }.joined(separator: " ")
        }
        if let name = Auth.auth().currentUser?.displayName, !name.isEmpty { return name }
        if let email = Auth.auth().currentUser?.email,
           let handle = email.split(separator: "@").first {
            return handle.capitalized.replacingOccurrences(of: ".", with: " ")
        }
        return "Nomad Explorer"
    }

    private var handleText: String {
        if let h = externalHandle { return h }
        if let email = Auth.auth().currentUser?.email,
           let handle = email.split(separator: "@").first {
            return String(handle)
        }
        return "nomad"
    }

    private var passportNumber: String {
        let uid = externalUID ?? Auth.auth().currentUser?.uid ?? "NOMAD000000000"
        let digits = uid.uppercased().filter { $0.isLetter || $0.isNumber }
        let a = String(digits.prefix(4)).padding(toLength: 4, withPad: "0", startingAt: 0)
        let b = String(digits.dropFirst(4).prefix(4)).padding(toLength: 4, withPad: "0", startingAt: 0)
        return "NMD · \(a) · \(b)"
    }

    private var homeCity: String { homeCityName ?? "—" }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                header
                    .padding(.top, 12)
                    .padding(.horizontal, 20)

                tradingCard
                    .padding(.horizontal, 28)
                    .padding(.top, 6)

                if !isFriendMode {
                    shareButton
                        .padding(.horizontal, 28)
                        .padding(.top, 8)

                    AddFriendSection()
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                } else {
                    Spacer().frame(height: 32)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.Nomad.panelBlack, Color(hex: 0x0A0A1E)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        Text(isFriendMode ? "@\(handleText)" : "Profile")
            .font(.custom("CalSans-Regular", size: 22))
            .foregroundStyle(Color.Nomad.textPrimary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Trading Card

    private var tradingCard: some View {
        GeometryReader { geo in
            TradingCardFace(
                tilt: tilt,
                year: currentYear,
                fullName: displayName,
                handle: handleText,
                homeCity: homeCity,
                countries: totalCountries,
                cities: totalCities,
                trips: totalTrips,
                continents: totalContinents,
                distanceKm: totalDistanceKm,
                steps: totalSteps,
                passportNumber: passportNumber
            )
            .frame(width: geo.size.width, height: geo.size.height)
            .rotation3DEffect(
                .degrees(Double(tilt.width)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.8
            )
            .rotation3DEffect(
                .degrees(Double(-tilt.height)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.8
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: tilt)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = max(-20, min(20, value.translation.width / 6))
                        let y = max(-20, min(20, value.translation.height / 6))
                        tilt = CGSize(width: x, height: y)
                    }
                    .onEnded { _ in
                        tilt = .zero
                    }
            )
        }
        .aspectRatio(63.0 / 88.0, contentMode: .fit)
    }

    // MARK: - Journeys Section

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private var journeysSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("JOURNEYS")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.Nomad.textSecondary)
                    .tracking(1.5)

                Spacer()

                if onStartTrip != nil {
                    Button {
                        onStartTrip?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Log Trip")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color.Nomad.panelBlack)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.Nomad.accent)
                        .clipShape(Capsule())
                    }
                }
            }

            if trips.isEmpty {
                Text("No trips yet — tap Log Trip to start.")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.Nomad.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 6) {
                    ForEach(trips) { trip in
                        journeyRow(trip)
                    }
                }
            }
        }
    }

    private func journeyRow(_ trip: TripDocument) -> some View {
        Button {
            onTripTap?(trip)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    GeometryReader { geo in
                        RoutePreviewPath(routePreview: trip.routePreview, size: geo.size)
                    }
                }
                .frame(width: 44, height: 32)
                .background(Color.Nomad.globeBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.cityName)
                        .font(.custom("Inter-SemiBold", size: 14))
                        .foregroundStyle(Color.Nomad.textPrimary)
                        .lineLimit(1)
                    Text(Self.dateFormatter.string(from: trip.startDate))
                        .font(.custom("Inter-Regular", size: 11))
                        .foregroundStyle(Color.Nomad.textSecondary)
                }

                Spacer()

                Text(String(format: "%.1f km", trip.distanceMeters / 1000))
                    .font(.custom("Inter-Regular", size: 12))
                    .foregroundStyle(Color.Nomad.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: 0x020920).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.Nomad.surfaceBorder.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if onDeleteTrip != nil {
                Button(role: .destructive) {
                    onDeleteTrip?(trip)
                } label: {
                    Label("Delete Trip", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            shareImage = renderTradingCard()
            showShareSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("Share Card")
            }
            .font(AppFont.buttonLabel())
            .foregroundStyle(Color.Nomad.panelBlack)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.Nomad.accent)
            .cornerRadius(14)
        }
    }

    // MARK: - Shareable Image

    @MainActor
    private func renderTradingCard() -> UIImage {
        let card = TradingCardFace(
            tilt: .zero,
            year: currentYear,
            fullName: displayName,
            handle: handleText,
            homeCity: homeCity,
            countries: totalCountries,
            cities: totalCities,
            trips: totalTrips,
            continents: totalContinents,
            distanceKm: totalDistanceKm,
            steps: totalSteps,
            passportNumber: passportNumber
        )
        .frame(width: 630, height: 880)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }

    // MARK: - Continent mapping

    fileprivate static func continent(for code: String) -> String? {
        switch code.uppercased() {
        case "US","CA","MX","GT","BZ","SV","HN","NI","CR","PA","CU","DO","HT","JM","BS","PR":
            return "NA"
        case "BR","AR","CL","PE","CO","VE","EC","BO","PY","UY","GY","SR":
            return "SA"
        case "GB","IE","FR","DE","ES","PT","IT","NL","BE","LU","CH","AT","DK","SE","NO","FI","IS","PL","CZ","SK","HU","RO","BG","GR","HR","SI","RS","BA","MK","AL","ME","LT","LV","EE","BY","UA","MD","MT","CY","LI","MC","AD","SM","VA","XK":
            return "EU"
        case "CN","JP","KR","KP","IN","PK","BD","LK","NP","BT","MM","TH","VN","LA","KH","MY","SG","ID","PH","TW","HK","MO","MN","KZ","UZ","TM","KG","TJ","AF","IR","IQ","SA","AE","QA","BH","KW","OM","YE","JO","LB","SY","IL","PS","TR","GE","AM","AZ","MV","BN","TL":
            return "AS"
        case "EG","LY","TN","DZ","MA","EH","SD","SS","ET","ER","DJ","SO","KE","UG","RW","BI","TZ","MZ","ZW","ZM","MW","AO","NA","BW","ZA","SZ","LS","MG","MU","SC","KM","CV","SN","GM","GN","GW","SL","LR","CI","GH","TG","BJ","NG","NE","ML","BF","CM","CF","TD","CG","CD","GA","GQ":
            return "AF"
        case "AU","NZ","PG","FJ","SB","VU","NC","PF","WS","TO","KI","TV","NR","FM","MH","PW":
            return "OC"
        default: return nil
        }
    }
}

// MARK: - Trading Card Face

private struct TradingCardFace: View {
    let tilt: CGSize
    let year: Int
    let fullName: String
    let handle: String
    let homeCity: String
    let countries: Int
    let cities: Int
    let trips: Int
    let continents: Int
    let distanceKm: Double
    let steps: Int
    let passportNumber: String

    var body: some View {
        ZStack {
            // Base card
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Nomad.panelBlack)

            // Holo background layer (conic + radial)
            holoBackground
                .blendMode(.screen)
                .opacity(0.18)

            // Inner border (card edge)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.Nomad.surfaceBorder.opacity(0.15), lineWidth: 1)
                .padding(8)

            // Content
            VStack(spacing: 0) {
                topStrip
                    .padding(.bottom, 12)

                nameBlock
                    .padding(.bottom, 10)

                globePortrait
                    .padding(.bottom, 12)

                statsGrid
                    .padding(.bottom, 8)

                movesList
                    .padding(.bottom, 8)

                footer
            }
            .padding(18)

            // Holo shine overlay
            holoShine
                .allowsHitTesting(false)

            // Outer border
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.Nomad.surfaceBorder.opacity(0.20), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color(hex: 0x020920).opacity(0.6), radius: 30, x: 0, y: 16)
        .shadow(color: Color.Nomad.accent.opacity(0.18), radius: 20, x: 0, y: 0)
    }

    // MARK: - Holo Background

    private var holoBackground: some View {
        ZStack {
            AngularGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0x5E89DD),
                    Color(hex: 0xC8D7F3),
                    Color(hex: 0xD94F3D),
                    Color(hex: 0x5E89DD),
                    Color(hex: 0x2D62D3),
                    Color(hex: 0xC8D7F3),
                    Color(hex: 0x5E89DD)
                ]),
                center: .center,
                angle: .degrees(Double(tilt.width) * 10)
            )

            RadialGradient(
                gradient: Gradient(colors: [
                    Color.Nomad.accent.opacity(0.35),
                    Color.clear
                ]),
                center: UnitPoint(
                    x: 0.5 + Double(tilt.width) / 100,
                    y: 0.5 + Double(tilt.height) / 100
                ),
                startRadius: 0,
                endRadius: 280
            )
        }
    }

    // MARK: - Top Strip

    private var topStrip: some View {
        HStack {
            Text("NOMAD · \(String(year)) SET")
                .font(.custom("Inter-SemiBold", size: 9))
                .tracking(2.25)
                .foregroundStyle(Color.Nomad.star)

            Spacer()

            Text("EXPLORER")
                .font(.custom("Inter-SemiBold", size: 10))
                .tracking(1)
                .foregroundStyle(Color.Nomad.panelBlack)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    LinearGradient(
                        colors: [Color.Nomad.accent, Color.Nomad.star],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    // MARK: - Name Block

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fullName)
                .font(.custom("CalSans-Regular", size: 26))
                .foregroundStyle(Color.Nomad.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("@\(handle) · \(homeCity)")
                .font(.custom("Inter-Regular", size: 12))
                .foregroundStyle(Color.Nomad.accent)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Globe Portrait

    private var globePortrait: some View {
        ZStack {
            // Portrait background
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(hex: 0x0B1A38),
                            Color(hex: 0x020920)
                        ]),
                        center: UnitPoint(x: 0.5, y: 0.55),
                        startRadius: 0, endRadius: 160
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.Nomad.surfaceBorder.opacity(0.12), lineWidth: 1)
                )

            StarField()

            GlobeBall()

            // Rarity star (top-left)
            VStack {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.Nomad.accent.opacity(0.2))
                        Circle()
                            .stroke(Color.Nomad.accent, lineWidth: 1)
                        Text("★")
                            .font(.custom("CalSans-Regular", size: 16))
                            .foregroundStyle(Color.Nomad.accent)
                    }
                    .frame(width: 32, height: 32)
                    Spacer()
                }
                Spacer()
            }
            .padding(8)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 2) {
            CardStat(value: "\(countries)", label: "CTR")
            CardStat(value: "\(cities)", label: "CIT")
            CardStat(value: "\(trips)", label: "TRP")
            CardStat(value: "\(continents)", label: "CNT")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: 0x020920).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.Nomad.surfaceBorder.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Moves

    private var movesList: some View {
        VStack(spacing: 4) {
            MoveRow(
                name: "Long Haul",
                detail: "\(formatDistance(distanceKm)) km traveled",
                power: formatPower(Int(distanceKm))
            )
            MoveRow(
                name: "Pace Setter",
                detail: "\(formatSteps(steps)) steps logged",
                power: formatPower(steps)
            )
        }
    }

    private func formatDistance(_ km: Double) -> String {
        if km >= 1000 { return String(format: "%.1fk", km / 1000) }
        return String(format: "%.0f", km)
    }

    private func formatSteps(_ s: Int) -> String {
        if s >= 1_000_000 { return String(format: "%.2fM", Double(s) / 1_000_000) }
        if s >= 1000 { return String(format: "%.1fK", Double(s) / 1000) }
        return "\(s)"
    }

    private func formatPower(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1000 { return String(format: "%.0fK", Double(n) / 1000) }
        return "\(n)"
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(Color.Nomad.surfaceBorder.opacity(0.08))
                .frame(height: 1)

            HStack {
                Text(passportNumber)
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Color.Nomad.textSecondary)
                Spacer()
                Text("017 / ∞ · \(String(year))")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Color.Nomad.textSecondary)
            }
        }
    }

    // MARK: - Holo Shine

    private var holoShine: some View {
        GeometryReader { _ in
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.30),
                    .init(color: Color.white.opacity(0.08), location: 0.45),
                    .init(color: Color.Nomad.star.opacity(0.12), location: 0.50),
                    .init(color: Color.white.opacity(0.08), location: 0.55),
                    .init(color: .clear, location: 0.70)
                ],
                startPoint: shineStart,
                endPoint: shineEnd
            )
            .blendMode(.overlay)
        }
    }

    private var shineStart: UnitPoint {
        let offset = Double(tilt.width) / 60
        return UnitPoint(x: -0.2 - offset, y: 0)
    }

    private var shineEnd: UnitPoint {
        let offset = Double(tilt.width) / 60
        return UnitPoint(x: 1.2 - offset, y: 1)
    }
}

// MARK: - Card Stat

private struct CardStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.custom("CalSans-Regular", size: 20))
                .foregroundStyle(Color.Nomad.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.custom("Inter-Regular", size: 8))
                .tracking(1.6)
                .foregroundStyle(Color.Nomad.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// MARK: - Move Row

private struct MoveRow: View {
    let name: String
    let detail: String
    let power: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.custom("CalSans-Regular", size: 13))
                    .foregroundStyle(Color.Nomad.textPrimary)
                Text(detail)
                    .font(.custom("Inter-Regular", size: 10))
                    .foregroundStyle(Color.Nomad.textSecondary)
            }
            Spacer()
            Text(power)
                .font(.custom("CalSans-Regular", size: 16))
                .foregroundStyle(Color.Nomad.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: 0x020920).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.Nomad.surfaceBorder.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Globe Ball

private struct GlobeBall: View {
    // Fixed pin positions to mirror the reference design's land pattern.
    private let pins: [(x: Double, y: Double)] = [
        (0.35, 0.30), (0.62, 0.28), (0.48, 0.42),
        (0.30, 0.52), (0.58, 0.58), (0.44, 0.68)
    ]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.72
            ZStack {
                // Sphere
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.Nomad.accent.opacity(0.3),
                                Color.clear
                            ]),
                            center: UnitPoint(x: 0.35, y: 0.35),
                            startRadius: 0, endRadius: size * 0.6
                        )
                    )
                    .background(
                        Circle().fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: 0x0C2457),
                                    Color(hex: 0x020920)
                                ]),
                                center: .center,
                                startRadius: 0, endRadius: size * 0.5
                            )
                        )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: -4, y: -6)
                    .shadow(color: Color.Nomad.accent.opacity(0.3), radius: 12)

                // Meridians
                Ellipse()
                    .stroke(Color.Nomad.accent.opacity(0.25), lineWidth: 0.7)
                    .frame(width: size * 0.96, height: size * 0.24)
                Ellipse()
                    .stroke(Color.Nomad.accent.opacity(0.25), lineWidth: 0.7)
                    .frame(width: size * 0.24, height: size * 0.96)
                Ellipse()
                    .stroke(Color.Nomad.accent.opacity(0.15), lineWidth: 0.7)
                    .frame(width: size * 0.60, height: size * 0.96)

                // Country glow pins
                ForEach(0..<pins.count, id: \.self) { i in
                    Circle()
                        .fill(Color.Nomad.accent)
                        .frame(width: 5, height: 5)
                        .shadow(color: Color.Nomad.accent.opacity(0.9), radius: 4)
                        .offset(
                            x: (pins[i].x - 0.5) * size,
                            y: (pins[i].y - 0.5) * size
                        )
                }
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.52)
        }
    }
}

// MARK: - Star Field

private struct StarField: View {
    // Stable random positions seeded once.
    private static let stars: [(x: Double, y: Double, size: Double, opacity: Double)] = {
        var gen = SeededGenerator(seed: 42)
        return (0..<30).map { _ in
            (
                x: Double.random(in: 0...1, using: &gen),
                y: Double.random(in: 0...1, using: &gen),
                size: Double.random(in: 0.3...1.8, using: &gen),
                opacity: Double.random(in: 0.2...0.8, using: &gen)
            )
        }
    }()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<Self.stars.count, id: \.self) { i in
                    let s = Self.stars[i]
                    Circle()
                        .fill(Color.Nomad.star)
                        .frame(width: s.size, height: s.size)
                        .opacity(s.opacity)
                        .position(x: s.x * geo.size.width, y: s.y * geo.size.height)
                }
            }
        }
    }
}

// MARK: - Seeded Generator

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Add Friend Section

private struct AddFriendSection: View {
    @State private var handle = ""
    @State private var state: SearchState = .idle

    enum SearchState {
        case idle
        case loading
        case found(FoundUser)
        case alreadyFriend
        case notFound
        case added(String)
        case error(String)
    }

    var body: some View {
        VStack(spacing: 14) {
            divider

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text("@")
                        .font(.custom("CalSans-Regular", size: 16))
                        .foregroundStyle(Color.Nomad.textSecondary)
                    TextField("username", text: $handle)
                        .font(.custom("CalSans-Regular", size: 16))
                        .foregroundStyle(Color.Nomad.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { search() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.Nomad.globeBackground.opacity(0.45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.Nomad.surfaceBorder.opacity(0.15), lineWidth: 1)
                        )
                )

                Button(action: search) {
                    Group {
                        if case .loading = state {
                            ProgressView()
                                .tint(Color.Nomad.panelBlack)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.Nomad.panelBlack)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.Nomad.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(handle.trimmingCharacters(in: .whitespaces).isEmpty || {
                    if case .loading = state { return true }
                    return false
                }())
            }

            resultView
        }
    }

    @ViewBuilder
    private var resultView: some View {
        switch state {
        case .idle:
            EmptyView()

        case .loading:
            EmptyView()

        case .found(let user):
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: user.avatarHue / 360, saturation: 0.32, brightness: 0.75),
                                Color(hue: user.avatarHue / 360, saturation: 0.28, brightness: 0.42)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))

                Text("@\(user.handle)")
                    .font(.custom("CalSans-Regular", size: 16))
                    .foregroundStyle(Color.Nomad.textPrimary)

                Spacer(minLength: 0)

                Button {
                    addFriend(user)
                } label: {
                    Text("Add")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.Nomad.panelBlack)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.Nomad.accent)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.Nomad.globeBackground.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.Nomad.surfaceBorder.opacity(0.10), lineWidth: 1)
                    )
            )

        case .alreadyFriend:
            feedbackText("Already friends.", color: Color.Nomad.textSecondary)

        case .notFound:
            feedbackText("No user found with that handle.", color: Color.Nomad.textSecondary)

        case .added(let h):
            feedbackText("Added @\(h)!", color: Color.Nomad.accent)

        case .error(let msg):
            feedbackText(msg, color: .red.opacity(0.8))
        }
    }

    private func feedbackText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.custom("CalSans-Regular", size: 14))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var divider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.Nomad.surfaceBorder.opacity(0.12))
                .frame(height: 1)
            Text("ADD FRIENDS")
                .font(.custom("CalSans-Regular", size: 12))
                .tracking(1.6)
                .foregroundStyle(Color.Nomad.textSecondary)
            Rectangle()
                .fill(Color.Nomad.surfaceBorder.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func search() {
        let trimmed = handle.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }
        state = .loading
        Task {
            do {
                guard let user = try await FriendService.shared.searchUser(handle: trimmed) else {
                    state = .notFound
                    return
                }
                let already = try await FriendService.shared.isFriend(uid: user.uid)
                state = already ? .alreadyFriend : .found(user)
            } catch {
                state = .error("Something went wrong.")
            }
        }
    }

    private func addFriend(_ user: FoundUser) {
        Task {
            do {
                try await FriendService.shared.addFriend(friend: user)
                state = .added(user.handle)
                handle = ""
            } catch {
                state = .error("Couldn't add friend.")
            }
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#if DEBUG
#Preview {
    Color.Nomad.globeBackground.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            TravelerPassport(
                trips: [
                    TripDocument(id: "1", cityName: "Tokyo", startDate: Date(timeIntervalSinceNow: -86400 * 30),
                                 endDate: Date(timeIntervalSinceNow: -86400 * 30 + 7200), stepCount: 12000,
                                 distanceMeters: 8500, routePreview: [[35.68, 139.65]], visitedCountryCodes: ["JP"],
                                 placeCounts: ["food": 5, "culture": 3]),
                    TripDocument(id: "2", cityName: "Paris", startDate: Date(timeIntervalSinceNow: -86400 * 60),
                                 endDate: Date(timeIntervalSinceNow: -86400 * 60 + 5400), stepCount: 9500,
                                 distanceMeters: 6200, routePreview: [[48.85, 2.35]], visitedCountryCodes: ["FR"],
                                 placeCounts: ["culture": 4, "food": 2]),
                    TripDocument(id: "3", cityName: "Seattle", startDate: Date(timeIntervalSinceNow: -86400 * 10),
                                 endDate: Date(timeIntervalSinceNow: -86400 * 10 + 10800), stepCount: 15000,
                                 distanceMeters: 11000, routePreview: [[47.61, -122.33]], visitedCountryCodes: ["US"],
                                 placeCounts: ["food": 6, "nightlife": 2]),
                ],
                visitedCountryCodes: ["JP", "FR", "US"]
            )
        }
}
#endif
