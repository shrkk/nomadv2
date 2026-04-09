import SwiftUI

// AppFont — canonical font access point for all phases.
// Typography contract: 4 sizes, 2 weights (Regular 400, SemiBold 600).
// Source: D-03 (CONTEXT.md), UI-SPEC Typography section (Phase 03.2 redesign).
// All-Inter font set. Replaces Playfair Display for titles and subheadings.
enum AppFont {
    static func title() -> Font {
        .custom("Inter-SemiBold", size: 28)
    }
    static func subheading() -> Font {
        .custom("Inter-SemiBold", size: 20)
    }
    static func body() -> Font {
        .custom("Inter-Regular", size: 16)
    }
    static func caption() -> Font {
        .custom("Inter-Regular", size: 13)
    }
    // buttonLabel reuses the Body size slot (16pt) with SemiBold weight — not a fifth size.
    static func buttonLabel() -> Font {
        .custom("Inter-SemiBold", size: 16)
    }
}

#if DEBUG
struct FontValidationView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Title 28pt Inter SemiBold").font(AppFont.title())
            Text("Subheading 20pt Inter SemiBold").font(AppFont.subheading())
            Text("Body 16pt Inter Regular").font(AppFont.body())
            Text("Caption 13pt Inter Regular").font(AppFont.caption())
            Text("Button 16pt Inter SemiBold").font(AppFont.buttonLabel())
        }
        .padding()
        .onAppear {
            assert(UIFont(name: "Inter-Regular", size: 16) != nil, "Inter Regular not loaded")
            assert(UIFont(name: "Inter-SemiBold", size: 16) != nil, "Inter SemiBold not loaded")
        }
    }
}

#Preview {
    FontValidationView()
}
#endif
