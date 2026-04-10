import SwiftUI
import Photos

// PhotosPermissionScreen — Screen 5 of the onboarding flow.
// D-05: Pre-prompt explanation before native Photos dialog fires.
// Onboarding never blocks on denial — advance after any callback result.
// UI-SPEC Screen 5: cream background, photo icon, amber CTA.

struct PhotosPermissionScreen: View {
    var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundColor(Color.Nomad.textPrimary)

                Text("Bring your trips to life")
                    .font(AppFont.title())
                    .foregroundColor(Color.Nomad.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Nomad matches your photos to each trip by date and location, automatically building a gallery for every journey.")
                    .font(AppFont.body())
                    .foregroundColor(Color.Nomad.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
            }
            .padding(.horizontal, 16)

            Spacer()

            Button {
                Task { await requestPhotosPermission() }
            } label: {
                Text("Connect your photos")
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

    private func requestPhotosPermission() async {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            coordinator.advance()
        }
    }
}
