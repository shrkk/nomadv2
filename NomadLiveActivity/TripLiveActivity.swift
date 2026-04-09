import ActivityKit
import WidgetKit
import SwiftUI

// TripLiveActivity — ActivityKit widget for active trip recording.
// Implements Dynamic Island compact + expanded states and Lock Screen banner.
// Per D-06 (03.2-CONTEXT.md) and the Live Activity section of 03.2-UI-SPEC.md.

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            // MARK: Lock Screen Banner
            LockScreenBannerView(state: context.state)

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded State (long-press)
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedIslandView(state: context.state)
                }
            } compactLeading: {
                // MARK: Compact Leading — pulsing dot + elapsed
                CompactLeadingView(state: context.state)
            } compactTrailing: {
                // MARK: Compact Trailing — distance
                CompactTrailingView(state: context.state)
            } minimal: {
                // Minimal (when two Live Activities are active)
                PulsingDotView()
            }
        }
    }
}

// MARK: - Compact Leading

struct CompactLeadingView: View {
    let state: TripActivityAttributes.ContentState
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 4) {
            PulsingDotView()
            Text(elapsedCompact(seconds: state.elapsedSeconds))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }
}

// MARK: - Compact Trailing

struct CompactTrailingView: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        Text(distanceFormatted(km: state.distanceKm))
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .monospacedDigit()
    }
}

// MARK: - Expanded Island View

struct ExpandedIslandView: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            // Row 1: Recording header
            HStack(spacing: 8) {
                PulsingDotView()
                Text("Recording")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(elapsedCompact(seconds: state.elapsedSeconds))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            // Row 2: Stats — distance | divider | elapsed
            HStack(spacing: 0) {
                statBlock(
                    value: distanceFormatted(km: state.distanceKm),
                    label: "Distance"
                )
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 1, height: 28)
                statBlock(
                    value: elapsedDetailed(seconds: state.elapsedSeconds),
                    label: "Elapsed"
                )
            }

            // Row 3: Location
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.60))
                Text(locationDisplay(state.locationName))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.80))
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity)
    }

    private func locationDisplay(_ name: String) -> String {
        name == "Locating..." ? name : String(name.prefix(30))
    }
}

// MARK: - Lock Screen Banner View

struct LockScreenBannerView: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center) {
            // Leading: dot + app name + location
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    PulsingDotView()
                    Text("Nomad")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                }
                Text(locationDisplay(state.locationName))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            // Trailing: distance + elapsed
            VStack(alignment: .trailing, spacing: 4) {
                Text(distanceDisplay(km: state.distanceKm))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(state.distanceKm < 0.1 ? .white.opacity(0.60) : .white)
                    .monospacedDigit()
                Text(elapsedCompact(seconds: state.elapsedSeconds))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.70))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func locationDisplay(_ name: String) -> String {
        name == "Locating..." ? name : String(name.prefix(30))
    }

    private func distanceDisplay(km: Double) -> String {
        km < 0.1 ? "Starting…" : distanceFormatted(km: km)
    }
}

// MARK: - Pulsing Dot

struct PulsingDotView: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.5 : 1.0)
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - Formatting Helpers

/// "1h 23m" — hours and minutes only (compact compact display)
func elapsedCompact(seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    if h > 0 {
        return "\(h)h \(m)m"
    } else {
        return "\(m)m"
    }
}

/// "1h 23m 14s" — hours + minutes + seconds (expanded display)
func elapsedDetailed(seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 {
        return "\(h)h \(m)m \(s)s"
    } else if m > 0 {
        return "\(m)m \(s)s"
    } else {
        return "\(s)s"
    }
}

/// "4.2 mi" or "4.2 km" based on locale via MeasurementFormatter.
func distanceFormatted(km: Double) -> String {
    let measurement = Measurement(value: km * 1000, unit: UnitLength.meters)
    let formatter = MeasurementFormatter()
    formatter.unitStyle = .short
    formatter.numberFormatter.maximumFractionDigits = 1
    formatter.unitOptions = .naturalScale
    return formatter.string(from: measurement)
}
