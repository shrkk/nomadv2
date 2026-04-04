import SwiftUI

// AppFont — canonical font access point for all phases.
// Typography contract: 4 sizes, 2 weights (Regular 400, Semibold 600).
// Source: D-08 (CONTEXT.md), DSYS-01, DSYS-02, UI-SPEC AppFont Implementation Contract.
// Note: largeTitle (34pt) was removed from the contract per UI-SPEC to comply with
// the 4-size maximum. Title (28pt) is the top of the scale.
enum AppFont {
    static func title() -> Font {
        .custom("PlayfairDisplay-SemiBold", size: 28)
    }
    static func subheading() -> Font {
        .custom("PlayfairDisplay-Regular", size: 20)
    }
    static func body() -> Font {
        .custom("Inter-Regular", size: 16)
    }
    static func caption() -> Font {
        .custom("Inter-Regular", size: 13)
    }
    // buttonLabel reuses the Body size slot (16pt) with Semibold weight — not a fifth size.
    static func buttonLabel() -> Font {
        .custom("Inter-SemiBold", size: 16)
    }
}

#if DEBUG
struct FontValidationView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Title 28pt Playfair Semibold").font(AppFont.title())
            Text("Subheading 20pt Playfair Regular").font(AppFont.subheading())
            Text("Body 16pt Inter Regular").font(AppFont.body())
            Text("Caption 13pt Inter Regular").font(AppFont.caption())
            Text("Button 16pt Inter Semibold").font(AppFont.buttonLabel())
        }
        .padding()
        .onAppear {
            assert(UIFont(name: "PlayfairDisplay-Regular", size: 20) != nil, "Playfair Regular not loaded")
            assert(UIFont(name: "PlayfairDisplay-SemiBold", size: 28) != nil, "Playfair SemiBold not loaded")
            assert(UIFont(name: "Inter-Regular", size: 16) != nil, "Inter Regular not loaded")
            assert(UIFont(name: "Inter-SemiBold", size: 16) != nil, "Inter SemiBold not loaded")
        }
    }
}

#Preview {
    FontValidationView()
}
#endif
