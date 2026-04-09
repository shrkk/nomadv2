import WidgetKit
import SwiftUI

// NomadLiveActivityBundle — entry point for the NomadLiveActivity widget extension.
// Xcode requires a @main WidgetBundle in every widget extension target.

@main
struct NomadLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TripLiveActivity()
    }
}
