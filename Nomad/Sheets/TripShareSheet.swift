import SwiftUI

// MARK: - TripShareSheet
//
// Share modal matching the Claude Design handoff.
// Card is the dominant element with a tilt-on-grab interaction (like the passport).
// Controls live in a compact settings drawer beneath.

struct TripShareSheet: View {
    let trip: TripDocument

    @State private var template: ShareTemplate = .cartographic
    @State private var cardFormat: CardFormat = .vertical
    @State private var cardFont: CardFontSystem = .classic
    @State private var cardLang: CardLanguage = .en
    @State private var showShareSheet = false
    @State private var shareImage: UIImage? = nil
    @State private var tilt: CGSize = .zero
    @State private var isHeld = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: 0x020920).opacity(0.96).ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader
                    .padding(.top, 52)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 6)

                tiltCardArea

                settingsDrawer
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ShareSheet(items: [img])
            }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Text("Share Trip")
                .font(.custom("CalSans-Regular", size: 20))
                .foregroundStyle(Color(hex: 0xE1E2F0))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xE1E2F0))
                    .frame(width: 30, height: 30)
                    .background(Color(hex: 0x0F0F28).opacity(0.5))
                    .overlay(Circle().stroke(Color(hex: 0xC8D7F3).opacity(0.2), lineWidth: 1))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Tilt Card Area

    private var tiltCardArea: some View {
        GeometryReader { geo in
            let cardW: CGFloat = 280
            let cardH: CGFloat = cardFormat == .vertical ? 498 : 280
            let scale = min((geo.size.width - 36) / cardW, (geo.size.height - 24) / cardH, 1.0)

            ZStack {
                shareCardView
                    .frame(width: cardW, height: cardH)
                    .scaleEffect(scale, anchor: .center)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(isHeld ? 0.7 : 0.55),
                            radius: isHeld ? 40 : 24, x: 0, y: isHeld ? 20 : 12)
                    .rotation3DEffect(.degrees(Double(tilt.width)), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
                    .rotation3DEffect(.degrees(Double(-tilt.height)), axis: (x: 1, y: 0, z: 0), perspective: 0.8)
                    .scaleEffect(isHeld ? 1.02 : 1.0)
                    .animation(.spring(response: isHeld ? 0.08 : 0.52, dampingFraction: isHeld ? 0.9 : 0.65), value: tilt)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHeld)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                isHeld = true
                                let rx = max(-18, min(18, val.translation.width / 8))
                                let ry = max(-14, min(14, val.translation.height / 8))
                                tilt = CGSize(width: rx, height: ry)
                            }
                            .onEnded { _ in
                                isHeld = false
                                tilt = .zero
                            }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.vertical, 8)

    }

    // MARK: - Card Renderer

    @ViewBuilder
    private var shareCardView: some View {
        switch template {
        case .cartographic:
            CartographicShareCard(trip: trip, lang: cardLang, fontSystem: cardFont,
                                  format: cardFormat)
        case .editorial:
            EditorialShareCard(trip: trip, lang: cardLang, fontSystem: cardFont,
                               format: cardFormat)
        case .photo:
            PhotoShareCard(trip: trip, lang: cardLang, fontSystem: cardFont,
                           format: cardFormat)
        }
    }

    // MARK: - Settings Drawer

    private var settingsDrawer: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                // Template
                DrawerCard(title: "Template", subtitle: "Pick a visual style") {
                    SegmentedPicker(
                        options: ShareTemplate.allCases.map { ($0.rawValue, $0.label) },
                        selected: template.rawValue,
                        onChange: { v in template = ShareTemplate(rawValue: v) ?? .cartographic }
                    )
                }

                // Format
                DrawerCard(title: "Format", subtitle: "Aspect ratio") {
                    SegmentedPicker(
                        options: [("vertical", "Story  9:16"), ("square", "Square  1:1")],
                        selected: cardFormat.rawValue,
                        onChange: { v in cardFormat = CardFormat(rawValue: v) ?? .vertical }
                    )
                }

                // Font
                DrawerCard(title: "Font", subtitle: "Typeface for the card") {
                    SegmentedPicker(
                        options: CardFontSystem.allCases.map { ($0.rawValue, $0.label) },
                        selected: cardFont.rawValue,
                        onChange: { v in cardFont = CardFontSystem(rawValue: v) ?? .classic }
                    )
                }

                // Card language
                DrawerCard(title: "Card language", subtitle: "Translate without changing the app") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                        ForEach(CardLanguage.allCases, id: \.self) { lang in
                            Button {
                                cardLang = lang
                            } label: {
                                VStack(spacing: 1) {
                                    Text(lang.code)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(cardLang == lang
                                            ? Color(hex: 0x0F0F28).opacity(0.55)
                                            : Color(hex: 0xA2A6CC))
                                    Text(lang.displayName)
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(cardLang == lang
                                            ? Color(hex: 0x0F0F28)
                                            : Color(hex: 0xA2A6CC))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(cardLang == lang ? Color(hex: 0xE1E2F0) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .shadow(color: cardLang == lang ? .black.opacity(0.35) : .clear,
                                        radius: 6, y: 3)
                                .animation(.easeInOut(duration: 0.16), value: cardLang)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(Color(hex: 0x020920).opacity(0.55))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xC8D7F3).opacity(0.06), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Actions
                HStack(spacing: 8) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Copy Link", systemImage: "link")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xE1E2F0))
                            .frame(height: 44)
                            .padding(.horizontal, 14)
                            .background(Color(hex: 0x020920).opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xC8D7F3).opacity(0.12), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        shareImage = renderCard()
                        showShareSheet = true
                    } label: {
                        Label("Export", systemImage: "arrow.down.to.line")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: 0x0F0F28))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.Nomad.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.40)
    }

    // MARK: - Render card as image

    @MainActor
    private func renderCard() -> UIImage {
        let w: CGFloat = 360
        let h: CGFloat = cardFormat == .vertical ? 640 : 360
        let view = shareCardView
            .frame(width: w, height: h)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}

// MARK: - Supporting types

enum ShareTemplate: String, CaseIterable {
    case cartographic, editorial, photo
    var label: String {
        switch self {
        case .cartographic: return "Map"
        case .editorial: return "Editorial"
        case .photo: return "Photo"
        }
    }
}

enum CardFormat: String, CaseIterable {
    case vertical, square
}

enum CardFontSystem: String, CaseIterable {
    case classic, modern, editorial, mono

    var label: String {
        switch self {
        case .classic: return "Classic"
        case .modern: return "Modern"
        case .editorial: return "Editorial"
        case .mono: return "Mono"
        }
    }

    var displayFont: String {
        switch self {
        case .classic: return "CalSans-Regular"
        case .modern: return "Inter-SemiBold"
        case .editorial: return "PlayfairDisplay-SemiBold"
        case .mono: return "Menlo"
        }
    }

    var bodyFont: String {
        switch self {
        case .classic, .editorial: return "Inter-Regular"
        case .modern: return "Inter-SemiBold"
        case .mono: return "Menlo"
        }
    }
}

enum CardLanguage: String, CaseIterable {
    case en, es, fr, ja, de, pt, it, ko, zh

    var code: String { rawValue.uppercased() }

    var displayName: String {
        switch self {
        case .en: return "English"
        case .es: return "Español"
        case .fr: return "Français"
        case .ja: return "日本語"
        case .de: return "Deutsch"
        case .pt: return "Português"
        case .it: return "Italiano"
        case .ko: return "한국어"
        case .zh: return "中文"
        }
    }

    func cityName(for city: String) -> String {
        let map: [String: [String: String]] = [
            "Kyoto": ["ja": "京都", "es": "Kioto", "pt": "Quioto", "ko": "교토", "zh": "京都"],
            "Tokyo": ["ja": "東京", "es": "Tokio", "pt": "Tóquio", "ko": "도쿄", "zh": "东京"],
            "Seoul": ["ja": "ソウル", "ko": "서울", "zh": "首尔"],
            "Paris": ["ja": "パリ", "es": "París", "ko": "파리", "zh": "巴黎"],
            "Lisbon": ["es": "Lisboa", "fr": "Lisbonne", "ja": "リスボン", "zh": "里斯本"],
        ]
        return map[city]?[rawValue] ?? city
    }

    var via: String {
        switch self {
        case .en: return "via"
        case .es: return "vía"
        case .fr: return "via"
        case .ja: return "提供:"
        case .de: return "via"
        case .pt: return "via"
        case .it: return "tramite"
        case .ko: return "제공:"
        case .zh: return "来自"
        }
    }

    var signature: String {
        switch self {
        case .en: return "~ a journey"
        case .es: return "~ un viaje"
        case .fr: return "~ un voyage"
        case .ja: return "〜 旅の記録"
        case .de: return "~ eine Reise"
        case .pt: return "~ uma viagem"
        case .it: return "~ un viaggio"
        case .ko: return "~ 하나의 여정"
        case .zh: return "~ 一次旅行"
        }
    }

    var recordedWith: String {
        switch self {
        case .en: return "Recorded with Nomad"
        case .es: return "Grabado con Nomad"
        case .fr: return "Enregistré avec Nomad"
        case .ja: return "Nomadで記録"
        case .de: return "Mit Nomad aufgenommen"
        case .pt: return "Gravado com Nomad"
        case .it: return "Registrato con Nomad"
        case .ko: return "Nomad으로 기록"
        case .zh: return "用 Nomad 记录"
        }
    }

    var fieldNotes: String {
        switch self {
        case .en: return "Nomad · Field Notes"
        case .es: return "Nomad · Apuntes de campo"
        case .fr: return "Nomad · Carnet de route"
        case .ja: return "Nomad・フィールドノート"
        case .de: return "Nomad · Feldnotizen"
        case .pt: return "Nomad · Notas de campo"
        case .it: return "Nomad · Appunti di viaggio"
        case .ko: return "Nomad · 필드 노트"
        case .zh: return "Nomad · 旅行手记"
        }
    }
}

// MARK: - DrawerCard

private struct DrawerCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("CalSans-Regular", size: 14))
                    .foregroundStyle(Color(hex: 0xE1E2F0))
                Text(subtitle)
                    .font(.custom("Inter-Regular", size: 11))
                    .foregroundStyle(Color(hex: 0x8E92C6))
            }
            .padding(.leading, 2)
            content()
        }
        .padding(12)
        .background(Color(hex: 0x0F0F28).opacity(0.92))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xC8D7F3).opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - SegmentedPicker

private struct SegmentedPicker: View {
    let options: [(id: String, label: String)]
    let selected: String
    let onChange: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.id) { opt in
                Button { onChange(opt.id) } label: {
                    Text(opt.label)
                        .font(.system(size: 12, weight: opt.id == selected ? .bold : .medium))
                        .foregroundStyle(opt.id == selected ? Color(hex: 0x0F0F28) : Color(hex: 0xA2A6CC))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(opt.id == selected ? Color(hex: 0xE1E2F0) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: opt.id == selected ? .black.opacity(0.35) : .clear, radius: 6, y: 3)
                        .animation(.easeInOut(duration: 0.16), value: selected)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(hex: 0x020920).opacity(0.55))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xC8D7F3).opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - CartographicShareCard

struct CartographicShareCard: View {
    let trip: TripDocument
    let lang: CardLanguage
    let fontSystem: CardFontSystem
    let format: CardFormat

    private var isSquare: Bool { format == .square }
    private var cityName: String { lang.cityName(for: trip.cityName) }
    private var countryCode: String { trip.visitedCountryCodes.first ?? "" }
    private var durationText: String {
        let mins = Int(trip.endDate.timeIntervalSince(trip.startDate) / 60)
        let h = mins / 60; let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()

    var body: some View {
        ZStack {
            // Background
            Color(hex: 0x0F0F28)

            // Subtle atmospheric gradient
            LinearGradient(
                colors: [Color(hex: 0x5E89DD).opacity(0.12), .clear],
                startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.6)
            )

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(countryCode)
                            .font(.system(size: 11, weight: .medium))
                            .tracking(0.6)
                            .foregroundStyle(Color(hex: 0x8E92C6))
                            .textCase(.uppercase)
                        Text(cityName)
                            .font(.custom(fontSystem.displayFont, size: isSquare ? 32 : 38))
                            .foregroundStyle(Color(hex: 0xE1E2F0))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(Self.dateFmt.string(from: trip.startDate))
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: 0x8E92C6))
                    }
                    Spacer()
                    Circle()
                        .stroke(Color(hex: 0xC8D7F3).opacity(0.3), lineWidth: 1)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "globe")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: 0xE1E2F0))
                        )
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 12)

                // Route preview
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: 0x020920).opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xC8D7F3).opacity(0.10), lineWidth: 1)
                        )
                    GeometryReader { geo in
                        RoutePreviewPath(routePreview: trip.routePreview, size: geo.size)
                            .padding(16)
                    }
                }
                .frame(height: isSquare ? 100 : 180)
                .padding(.horizontal, 16)

                // Coordinates strip
                HStack {
                    let coord = trip.routePreview.first
                    if let lat = coord?.first, let lon = coord?.last {
                        Text(String(format: "%.4f° N", lat))
                        Spacer()
                        Text("━━━━━━━")
                            .opacity(0.4)
                        Spacer()
                        Text(String(format: "%.4f° E", lon))
                    }
                }
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(Color(hex: 0x8E92C6))
                .tracking(0.4)
                .padding(.horizontal, 24)
                .padding(.top, 10)

                Spacer()

                // Stats
                HStack(spacing: 0) {
                    cardStat(value: String(format: "%.1f", trip.distanceMeters / 1000),
                             label: "km", leading: true)
                    Rectangle()
                        .fill(Color(hex: 0xC8D7F3).opacity(0.15))
                        .frame(width: 1, height: 32)
                    cardStat(value: durationText, label: "duration")
                    Rectangle()
                        .fill(Color(hex: 0xC8D7F3).opacity(0.15))
                        .frame(width: 1, height: 32)
                    cardStat(value: stepsLabel, label: "steps")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

                // Footer
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.Nomad.accent)
                            .frame(width: 4, height: 4)
                        Text("NOMAD")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(0.4)
                    }
                    Spacer()
                    Text("\(trip.placeCounts.values.reduce(0, +)) stops")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.4)
                }
                .foregroundStyle(Color(hex: 0x8E92C6))
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var stepsLabel: String {
        let s = trip.stepCount
        if s >= 1000 { return String(format: "%.1fk", Double(s) / 1000) }
        return "\(s)"
    }

    private func cardStat(value: String, label: String, leading: Bool = false) -> some View {
        VStack(alignment: leading ? .leading : .center, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(Color(hex: 0x8E92C6).opacity(0.85))
            Text(value)
                .font(.custom(fontSystem.displayFont, size: 22))
                .foregroundStyle(Color(hex: 0xE1E2F0))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .center)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
    }
}

// MARK: - EditorialShareCard

struct EditorialShareCard: View {
    let trip: TripDocument
    let lang: CardLanguage
    let fontSystem: CardFontSystem
    let format: CardFormat

    private var isSquare: Bool { format == .square }
    private var cityName: String { lang.cityName(for: trip.cityName) }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: 0xF4F1EA)

            VStack(alignment: .leading, spacing: 0) {
                // "Issue" strip
                HStack {
                    Text(lang.fieldNotes)
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.5)
                        .textCase(.uppercase)
                    Spacer()
                    Text("№ \(String(trip.id.prefix(4)).uppercased())")
                        .font(.system(size: 9.5, weight: .medium))
                        .tracking(1)
                }
                .foregroundStyle(Color(hex: 0x0F0F28))
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)

                Rectangle()
                    .fill(Color(hex: 0x0F0F28).opacity(0.15))
                    .frame(height: 1)

                // Date + country
                Text("\(Self.dateFmt.string(from: trip.startDate)) · \(trip.visitedCountryCodes.first ?? "")")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(Color(hex: 0x0F0F28).opacity(0.6))
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                // City — big italic
                Text(cityName)
                    .font(.custom("PlayfairDisplay-SemiBold", size: isSquare ? 52 : 72))
                    .italic()
                    .foregroundStyle(Color(hex: 0x0F0F28))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                // Summary
                Text("\(trip.placeCounts.values.reduce(0, +)) stops · \(String(format: "%.1f km", trip.distanceMeters / 1000)) on foot")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0x0F0F28).opacity(0.6))
                    .padding(.horizontal, 24)
                    .padding(.top, 6)

                // Route line drawing
                GeometryReader { geo in
                    RoutePreviewPath(
                        routePreview: trip.routePreview,
                        size: geo.size,
                        strokeColor: Color(hex: 0x0F0F28),
                        lineWidth: 1.2
                    )
                    .padding(.horizontal, 24)
                }
                .frame(height: isSquare ? 70 : 140)
                .padding(.top, 12)

                Spacer()

                Rectangle()
                    .fill(Color(hex: 0x0F0F28).opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 24)

                // Stats
                HStack(spacing: 0) {
                    editorialStat(value: String(format: "%.1f", trip.distanceMeters / 1000), label: "km")
                    editorialStat(value: durationText, label: "duration")
                    editorialStat(value: stepsLabel, label: "steps")
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Footer
                HStack {
                    Text(lang.recordedWith)
                    Spacer()
                    Text(lang.signature)
                        .font(.custom("PlayfairDisplay-SemiBold", size: 14))
                        .italic()
                        .foregroundStyle(Color(hex: 0x0F0F28))
                }
                .font(.system(size: 9.5, weight: .medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: 0x0F0F28).opacity(0.5))
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 22)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var durationText: String {
        let mins = Int(trip.endDate.timeIntervalSince(trip.startDate) / 60)
        let h = mins / 60; let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private var stepsLabel: String {
        let s = trip.stepCount
        if s >= 1000 { return String(format: "%.1fk", Double(s) / 1000) }
        return "\(s)"
    }

    private func editorialStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Color(hex: 0x0F0F28).opacity(0.55))
            Text(value)
                .font(.custom("PlayfairDisplay-SemiBold", size: 22))
                .italic()
                .foregroundStyle(Color(hex: 0x0F0F28))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
}

// MARK: - PhotoShareCard

struct PhotoShareCard: View {
    let trip: TripDocument
    let lang: CardLanguage
    let fontSystem: CardFontSystem
    let format: CardFormat

    private var isSquare: Bool { format == .square }
    private var cityName: String { lang.cityName(for: trip.cityName) }
    private var accent: Color { Color.Nomad.accent }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()

    var body: some View {
        ZStack {
            // Procedural photo background (warm gradient)
            LinearGradient(
                colors: [
                    Color(hue: 0.08, saturation: 0.55, brightness: 0.25),
                    Color(hue: 0.05, saturation: 0.70, brightness: 0.12),
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Dim overlay
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.15), location: 0),
                    .init(color: .black.opacity(0.55), location: 0.6),
                    .init(color: .black.opacity(0.75), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                // Top bar
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .stroke(Color.white, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "globe")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white)
                            )
                        Text("NOMAD")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    Text(Self.dateFmt.string(from: trip.startDate))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Route
                GeometryReader { geo in
                    RoutePreviewPath(
                        routePreview: trip.routePreview,
                        size: geo.size,
                        strokeColor: accent,
                        lineWidth: 2.5
                    )
                }
                .frame(height: isSquare ? 100 : 180)
                .padding(.top, 8)

                Spacer()

                // City block
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.visitedCountryCodes.first?.uppercased() ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(0.4)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(cityName)
                        .font(.custom(fontSystem.displayFont, size: isSquare ? 36 : 50))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(.horizontal, 20)

                // Stats
                HStack(spacing: 12) {
                    photoStat(value: String(format: "%.1f km", trip.distanceMeters / 1000), label: "distance")
                    photoStat(value: durationText, label: "duration")
                    photoStat(value: stepsLabel, label: "steps")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Footer
                HStack {
                    Text("@nomad · #travel")
                    Spacer()
                    Text("\(lang.via) NOMAD")
                }
                .font(.system(size: 10.5, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 22)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var durationText: String {
        let mins = Int(trip.endDate.timeIntervalSince(trip.startDate) / 60)
        let h = mins / 60; let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private var stepsLabel: String {
        let s = trip.stepCount
        if s >= 1000 { return String(format: "%.1fk", Double(s) / 1000) }
        return "\(s)"
    }

    private func photoStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
