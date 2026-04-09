import SwiftUI

// DiscoveryScopeScreen — Screen 6 of the onboarding flow.
// D-06: Two large tappable option cards. "awayOnly" pre-selected per UI-SPEC.
// UI-SPEC Screen 6: cream background, two full-width cards, amber selected state.

struct DiscoveryScopeScreen: View {
    var coordinator: OnboardingCoordinator

    @State private var selectedScope: String = "awayOnly"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("When should Nomad log trips?")
                .font(AppFont.title())
                .foregroundColor(Color.Nomad.textPrimary)
                .padding(.top, 32)
                .padding(.horizontal, 16)

            Text("You can change this anytime in settings.")
                .font(AppFont.caption())
                .foregroundColor(Color.Nomad.textSecondary)
                .padding(.top, 8)
                .padding(.horizontal, 16)

            VStack(spacing: 16) {
                ScopeCard(
                    icon: "globe",
                    label: "Everywhere",
                    description: "Log trips wherever you go.",
                    value: "everywhere",
                    selectedScope: $selectedScope
                )

                ScopeCard(
                    icon: "house",
                    label: "Away from home only",
                    description: "Only log trips when you leave your home city.",
                    value: "awayOnly",
                    selectedScope: $selectedScope
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 32)

            Spacer()

            Button {
                coordinator.discoveryScope = selectedScope
                coordinator.advance()
            } label: {
                Text("Continue")
                    .font(AppFont.buttonLabel())
                    .foregroundColor(Color.Nomad.panelBlack)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.Nomad.accent)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Nomad.panelBlack.ignoresSafeArea())
    }
}

// MARK: - Scope option card

private struct ScopeCard: View {
    let icon: String
    let label: String
    let description: String
    let value: String
    @Binding var selectedScope: String

    @State private var isTapping: Bool = false

    private var isSelected: Bool { selectedScope == value }

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25, bounce: 0.3)) {
                selectedScope = value
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color.Nomad.textPrimary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(AppFont.buttonLabel())
                        .foregroundColor(Color.Nomad.textPrimary)

                    Text(description)
                        .font(AppFont.caption())
                        .foregroundColor(Color.Nomad.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.Nomad.accent)
                }
            }
            .padding(16)
            .frame(minHeight: 88)
            .background(isSelected ? Color.white.opacity(0.10) : Color.black.opacity(0.35))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.white : Color.white.opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isTapping ? 0.97 : 1.0)
        .animation(.spring(duration: 0.2, bounce: 0.4), value: isTapping)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isTapping = true }
                .onEnded { _ in isTapping = false }
        )
    }
}
