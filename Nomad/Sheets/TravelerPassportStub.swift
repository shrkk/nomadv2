import SwiftUI

// MARK: - TravelerPassport
//
// Passport-style travel stats view inspired by Flighty's passport design.
// Bold typography, country flags, dashed dividers, MRZ-style footer.

struct TravelerPassport: View {
    let trips: [TripDocument]
    let visitedCountryCodes: [String]
    var countries: [CountryFeature] = []
    var homeCityName: String? = nil
    var onTripTap: ((TripDocument) -> Void)? = nil
    var onDeleteTrip: ((TripDocument) -> Void)? = nil
    var onStartTrip: (() -> Void)? = nil

    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var mapPageIndex = 0  // 0 = map, 1 = journeys

    // MARK: - Computed Stats

    private var totalTrips: Int { trips.count }
    private var totalCountries: Int { Set(visitedCountryCodes).count }
    private var totalCities: Int { Set(trips.map(\.locality)).count }
    private var totalDistanceKm: Double { trips.reduce(0) { $0 + $1.distanceMeters } / 1000.0 }
    private var totalSteps: Int { trips.reduce(0) { $0 + $1.stepCount } }

    private var totalDurationHours: Double {
        trips.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 3600.0
    }

    private var topCity: String {
        let abroad = trips.filter { $0.locality != homeCityName }
        return Dictionary(grouping: abroad, by: \.locality)
            .max(by: { $0.value.count < $1.value.count })?.key ?? "—"
    }

    private var topCategory: String {
        var totals: [String: Int] = [:]
        for trip in trips { for (cat, count) in trip.placeCounts { totals[cat, default: 0] += count } }
        return totals.max(by: { $0.value < $1.value })?.key.capitalized ?? "—"
    }

    private var cityList: [String] {
        Array(Set(trips.map(\.locality))).sorted()
    }

    private var durationText: String {
        let h = Int(totalDurationHours)
        let m = Int((totalDurationHours - Double(h)) * 60)
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private var mrzLine: String {
        let year = Calendar.current.component(.year, from: Date())
        let cities = cityList.prefix(3).joined(separator: "<").uppercased()
        return "\(year)<<<NOMAD<<<\(cities)<<<PASSPORT<\(totalTrips)TRIPS"
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Country flags above the map
                flagStrip
                    .padding(.top, 4)

                // Map / Journeys swipeable area
                globeVisual
                    .padding(.top, 6)

                // Dashed divider
                dashedDivider
                    .padding(.top, 20)

                // Passport title
                passportHeader
                    .padding(.top, 20)
                    .padding(.horizontal, 28)

                // Big stats
                bigStats
                    .padding(.top, 24)
                    .padding(.horizontal, 28)

                // Secondary stats
                secondaryStats
                    .padding(.top, 20)
                    .padding(.horizontal, 28)

                // Dashed divider
                dashedDivider
                    .padding(.top, 24)

                // Fun facts
                funFacts
                    .padding(.top, 20)
                    .padding(.horizontal, 28)

                // MRZ footer
                mrzFooter
                    .padding(.top, 28)
                    .padding(.horizontal, 28)

                // Share button
                shareButton
                    .padding(.top, 24)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.Nomad.panelBlack, Color.Nomad.globeBackground],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.Nomad.panelBlack)
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: - Swipeable Map / Journeys

    private var globeVisual: some View {
        VStack(spacing: 6) {
            TabView(selection: $mapPageIndex) {
                mapPage
                    .tag(0)
                journeysPage
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: UIScreen.main.bounds.width * 0.65)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Page dots
            HStack(spacing: 6) {
                Circle()
                    .fill(mapPageIndex == 0 ? Color.Nomad.accent : Color.Nomad.surfaceBorder.opacity(0.3))
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(mapPageIndex == 1 ? Color.Nomad.accent : Color.Nomad.surfaceBorder.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 12)
    }

    private var mapPage: some View {
        Group {
            if countries.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.Nomad.landUnvisited.opacity(0.3))
                    .overlay(
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.Nomad.landVisited.opacity(0.25))
                    )
            } else {
                let mapImage = GlobeCountryOverlay.renderPassportMap(
                    countries: countries,
                    visitedCodes: Set(visitedCountryCodes)
                )
                Image(uiImage: mapImage)
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private var journeysPage: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("JOURNEYS")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.Nomad.textSecondary)
                    .tracking(1)

                Spacer()

                if onStartTrip != nil {
                    Button {
                        onStartTrip?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Log")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color.Nomad.accent)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if trips.isEmpty {
                Spacer()
                Text("No trips yet")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.Nomad.textSecondary)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(trips.prefix(10)) { trip in
                            Button {
                                onTripTap?(trip)
                            } label: {
                                HStack(spacing: 10) {
                                    // Route mini preview
                                    ZStack {
                                        GeometryReader { geo in
                                            RoutePreviewPath(routePreview: trip.routePreview, size: geo.size)
                                        }
                                    }
                                    .frame(width: 36, height: 28)
                                    .background(Color.Nomad.globeBackground.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(trip.cityName)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.Nomad.textPrimary)
                                            .lineLimit(1)
                                        Text(Self.dateFormatter.string(from: trip.startDate))
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.Nomad.textSecondary)
                                    }

                                    Spacer()

                                    Text(String(format: "%.1f km", trip.distanceMeters / 1000))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.Nomad.textSecondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .background(Color.Nomad.globeBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Flag Strip

    private var flagStrip: some View {
        HStack(spacing: 4) {
            ForEach(Array(Set(visitedCountryCodes)).sorted(), id: \.self) { code in
                Text(flagEmoji(for: code))
                    .font(.system(size: 20))
            }
        }
    }

    // MARK: - Dashed Divider

    private var dashedDivider: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 1)
            .overlay(
                GeometryReader { geo in
                    Path { path in
                        path.move(to: .zero)
                        path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundStyle(Color.Nomad.accent.opacity(0.25))
                }
            )
            .padding(.horizontal, 28)
    }

    // MARK: - Passport Header

    private var passportHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MY NOMAD PASSPORT")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundStyle(Color.Nomad.textPrimary)
                    .tracking(1)

                Text("PASSPORT · PASS · PASAPORTE")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.Nomad.textSecondary.opacity(0.6))
            }

            Spacer()

            // App icon placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.Nomad.accent.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "figure.walk")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.Nomad.accent)
                )
        }
    }

    // MARK: - Big Stats

    private var bigStats: some View {
        HStack(alignment: .top, spacing: 0) {
            // Trips
            VStack(alignment: .leading, spacing: 2) {
                Text("JOURNEYS")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.Nomad.textSecondary)
                    .tracking(1)
                Text("\(totalTrips)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.Nomad.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Distance
            VStack(alignment: .leading, spacing: 2) {
                Text("DISTANCE")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.Nomad.textSecondary)
                    .tracking(1)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.0f", totalDistanceKm))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.Nomad.textPrimary)
                    Text("km")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.Nomad.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Secondary Stats

    private var secondaryStats: some View {
        HStack(alignment: .top, spacing: 0) {
            statColumn(label: "TIME", value: durationText)
            statColumn(label: "COUNTRIES", value: "\(totalCountries)")
            statColumn(label: "CITIES", value: "\(totalCities)")
        }
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.Nomad.textSecondary)
                .tracking(1)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color.Nomad.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Fun Facts

    private var funFacts: some View {
        VStack(spacing: 14) {
            funFactRow(emoji: "👟", label: "TOTAL STEPS", value: formatNumber(totalSteps))
            funFactRow(emoji: "📍", label: "FAV CITY ABROAD", value: topCity)
            funFactRow(emoji: "❤️", label: "TOP ACTIVITY", value: topCategory)
        }
    }

    private func funFactRow(emoji: String, label: String, value: String) -> some View {
        HStack {
            Text(emoji)
                .font(.system(size: 20))

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.Nomad.textSecondary)
                .tracking(1)

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.Nomad.textPrimary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.Nomad.globeBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.Nomad.surfaceBorder.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - MRZ Footer

    private var mrzFooter: some View {
        VStack(spacing: 4) {
            Text(mrzLine)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.Nomad.textSecondary.opacity(0.4))
                .lineLimit(1)
                .truncationMode(.tail)

            Text("nomad — turn miles into memories")
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.Nomad.textSecondary.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            shareImage = renderPassportCard()
            showShareSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("Share Passport")
            }
            .font(AppFont.buttonLabel())
            .foregroundStyle(Color.Nomad.panelBlack)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.Nomad.accent)
            .cornerRadius(14)
        }
    }

    // MARK: - Shareable Card Renderer

    @MainActor
    private func renderPassportCard() -> UIImage {
        let w: CGFloat = 390
        let h: CGFloat = 780
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let gc = ctx.cgContext
            let m: CGFloat = 28 // margin

            // Background gradient
            let bgColors = [UIColor(hex: 0x0F0F28).cgColor, UIColor(hex: 0x020920).cgColor]
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: bgColors as CFArray, locations: [0, 1])!
            gc.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: h), options: [])

            // Outer border
            gc.setStrokeColor(UIColor(hex: 0x5E89DD, alpha: 0.25).cgColor)
            gc.setLineWidth(2)
            gc.addPath(UIBezierPath(roundedRect: CGRect(x: 1, y: 1, width: w - 2, height: h - 2),
                                     cornerRadius: 24).cgPath)
            gc.strokePath()

            // Globe placeholder
            let globeRect = CGRect(x: m, y: 30, width: w - m * 2, height: 160)
            gc.setFillColor(UIColor(hex: 0x0C2457, alpha: 0.4).cgColor)
            gc.addPath(UIBezierPath(roundedRect: globeRect, cornerRadius: 14).cgPath)
            gc.fillPath()

            // Flags
            var y: CGFloat = 210
            let flagStr = Array(Set(visitedCountryCodes)).sorted()
                .map { flagEmoji(for: $0) }.joined(separator: "  ")
            let flagAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 28)]
            (flagStr as NSString).draw(at: CGPoint(x: m, y: y), withAttributes: flagAttrs)

            // Dashed line
            y += 50
            gc.setStrokeColor(UIColor(hex: 0x5E89DD, alpha: 0.2).cgColor)
            gc.setLineWidth(1)
            gc.setLineDash(phase: 0, lengths: [6, 4])
            gc.move(to: CGPoint(x: m, y: y))
            gc.addLine(to: CGPoint(x: w - m, y: y))
            gc.strokePath()
            gc.setLineDash(phase: 0, lengths: [])

            // Title
            y += 16
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Inter-SemiBold", size: 20) ?? .boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor(hex: 0xE1E2F0),
            ]
            ("MY NOMAD PASSPORT" as NSString).draw(at: CGPoint(x: m, y: y), withAttributes: titleAttrs)

            y += 28
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .medium),
                .foregroundColor: UIColor(hex: 0x8E92C6, alpha: 0.6),
            ]
            ("PASSPORT · PASS · PASAPORTE" as NSString).draw(at: CGPoint(x: m, y: y), withAttributes: subAttrs)

            // Big stats
            y += 36
            let bigAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 52, weight: .bold),
                .foregroundColor: UIColor(hex: 0xE1E2F0),
            ]
            let unitAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .medium),
                .foregroundColor: UIColor(hex: 0x8E92C6),
            ]
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor(hex: 0x8E92C6),
            ]

            ("JOURNEYS" as NSString).draw(at: CGPoint(x: m, y: y), withAttributes: labelAttrs)
            ("DISTANCE" as NSString).draw(at: CGPoint(x: 200, y: y), withAttributes: labelAttrs)
            y += 16
            ("\(totalTrips)" as NSString).draw(at: CGPoint(x: m, y: y), withAttributes: bigAttrs)
            let distStr = String(format: "%.0f", totalDistanceKm)
            (distStr as NSString).draw(at: CGPoint(x: 200, y: y), withAttributes: bigAttrs)
            let distSize = (distStr as NSString).size(withAttributes: bigAttrs)
            ("km" as NSString).draw(at: CGPoint(x: 200 + distSize.width + 4, y: y + 26), withAttributes: unitAttrs)

            // Secondary stats
            y += 72
            let medAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .bold),
                .foregroundColor: UIColor(hex: 0xE1E2F0),
            ]
            let col1: CGFloat = m
            let col2: CGFloat = 150
            let col3: CGFloat = 270

            ("TIME" as NSString).draw(at: CGPoint(x: col1, y: y), withAttributes: labelAttrs)
            ("COUNTRIES" as NSString).draw(at: CGPoint(x: col2, y: y), withAttributes: labelAttrs)
            ("CITIES" as NSString).draw(at: CGPoint(x: col3, y: y), withAttributes: labelAttrs)
            y += 14
            (durationText as NSString).draw(at: CGPoint(x: col1, y: y), withAttributes: medAttrs)
            ("\(totalCountries)" as NSString).draw(at: CGPoint(x: col2, y: y), withAttributes: medAttrs)
            ("\(totalCities)" as NSString).draw(at: CGPoint(x: col3, y: y), withAttributes: medAttrs)

            // Dashed line
            y += 52
            gc.setStrokeColor(UIColor(hex: 0x5E89DD, alpha: 0.2).cgColor)
            gc.setLineDash(phase: 0, lengths: [6, 4])
            gc.move(to: CGPoint(x: m, y: y))
            gc.addLine(to: CGPoint(x: w - m, y: y))
            gc.strokePath()
            gc.setLineDash(phase: 0, lengths: [])

            // Fun facts
            y += 16
            let factAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Inter-SemiBold", size: 15) ?? .boldSystemFont(ofSize: 15),
                .foregroundColor: UIColor(hex: 0xE1E2F0),
            ]
            let facts = [
                ("👟", "STEPS", formatNumber(totalSteps)),
                ("📍", "FAV ABROAD", topCity),
                ("❤️", "ACTIVITY", topCategory),
            ]
            for (emoji, lbl, val) in facts {
                let line = "\(emoji)  \(lbl)"
                (line as NSString).draw(at: CGPoint(x: m, y: y), withAttributes: labelAttrs)
                (val as NSString).draw(at: CGPoint(x: w - m - (val as NSString).size(withAttributes: factAttrs).width, y: y - 2), withAttributes: factAttrs)
                y += 28
            }

            // MRZ
            y = h - 50
            let mrzAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 8, weight: .regular),
                .foregroundColor: UIColor(hex: 0x8E92C6, alpha: 0.35),
            ]
            (mrzLine as NSString).draw(at: CGPoint(x: m, y: y), withAttributes: mrzAttrs)
            ("nomad — turn miles into memories" as NSString).draw(
                at: CGPoint(x: m, y: y + 14), withAttributes: mrzAttrs)
        }
    }

    // MARK: - Helpers

    private func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        return countryCode.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(base + $0.value).map { String($0) }
        }.joined()
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
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
