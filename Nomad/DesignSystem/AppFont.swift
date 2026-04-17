import SwiftUI

// AppFont — canonical font access point for all phases.
// Cal Sans for titles/subheadings, Inter for body/caption/buttons.
enum AppFont {
    static func title() -> Font {
        .custom("CalSans-Regular", size: 28)
    }
    static func subheading() -> Font {
        .custom("CalSans-Regular", size: 20)
    }
    static func body() -> Font {
        .custom("Inter-Regular", size: 16)
    }
    static func caption() -> Font {
        .custom("Inter-Regular", size: 13)
    }
    static func buttonLabel() -> Font {
        .custom("Inter-SemiBold", size: 16)
    }
}

#if DEBUG
struct FontValidationView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Title 28pt Cal Sans").font(AppFont.title())
            Text("Subheading 20pt Cal Sans").font(AppFont.subheading())
            Text("Body 16pt Inter Regular").font(AppFont.body())
            Text("Caption 13pt Inter Regular").font(AppFont.caption())
            Text("Button 16pt Inter SemiBold").font(AppFont.buttonLabel())
        }
        .padding()
        .onAppear {
            assert(UIFont(name: "CalSans-Regular", size: 16) != nil, "Cal Sans not loaded")
            assert(UIFont(name: "Inter-Regular", size: 16) != nil, "Inter Regular not loaded")
            assert(UIFont(name: "Inter-SemiBold", size: 16) != nil, "Inter SemiBold not loaded")
        }
    }
}

#Preview {
    FontValidationView()
}
#endif
