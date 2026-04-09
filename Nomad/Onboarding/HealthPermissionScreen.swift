import SwiftUI
import HealthKit

// HealthPermissionScreen — Screen 6 of the onboarding flow.
// Requests HealthKit step count read authorization once during onboarding.
// Onboarding never blocks on denial — advance after any dialog result.

struct HealthPermissionScreen: View {
    var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 40))
                    .foregroundColor(Color.Nomad.textPrimary)

                Text("Count every step")
                    .font(AppFont.title())
                    .foregroundColor(Color.Nomad.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Nomad reads your step count from Apple Health to show how far you walked on each trip.")
                    .font(AppFont.body())
                    .foregroundColor(Color.Nomad.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
            }
            .padding(.horizontal, 16)

            Spacer()

            Button {
                requestHealthPermission()
            } label: {
                Text("Connect Apple Health")
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

    // MARK: - Permission request

    private func requestHealthPermission() {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            coordinator.advance()
            return
        }
        let healthStore = HKHealthStore()
        healthStore.requestAuthorization(toShare: [], read: [stepType]) { _, _ in
            DispatchQueue.main.async {
                coordinator.advance()
            }
        }
    }
}
