import SwiftUI

// HandleScreen — Screen 3 of the onboarding flow.
// D-04: Live debounced Firestore uniqueness check (500ms).
// T-02-07: Client-side enforcement — lowercase alphanumeric + underscore only, max 30 chars.
// UI-SPEC Screen 3: cream background, "@" prefix field, inline validation states.

enum HandleState: Equatable {
    case idle
    case checking
    case available
    case taken
    case invalidFormat
}

struct HandleScreen: View {
    var coordinator: OnboardingCoordinator
    @Environment(AuthManager.self) private var authManager
    @Environment(UserService.self) private var userService

    @State private var handleText: String = ""
    @State private var handleState: HandleState = .idle
    @State private var isSubmitting: Bool = false
    @State private var submitError: String?
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Choose your handle")
                    .font(AppFont.title())
                    .foregroundColor(Color.Nomad.globeBackground)
                    .padding(.top, 32)

                Text("This is how other travelers will find you.")
                    .font(AppFont.body())
                    .foregroundColor(Color.Nomad.globeBackground.opacity(0.6))
                    .padding(.top, 8)

                handleField
                    .padding(.top, 32)

                validationCaption
                    .padding(.top, 4)

                if let error = submitError {
                    Text(error)
                        .font(AppFont.caption())
                        .foregroundColor(Color.Nomad.destructive)
                        .padding(.top, 4)
                }

                ctaButton
                    .padding(.top, 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.Nomad.cream.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: handleText) { _, newValue in
            onHandleTextChanged(newValue)
        }
    }

    // MARK: - Handle field

    private var handleField: some View {
        HStack(spacing: 4) {
            Text("@")
                .font(AppFont.body())
                .foregroundColor(Color.Nomad.globeBackground.opacity(0.6))
                .padding(.leading, 12)

            TextField("", text: $handleText)
                .font(AppFont.body())
                .foregroundColor(Color.Nomad.globeBackground)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)

            trailingIndicator
                .padding(.trailing, 12)
        }
        .frame(height: 48)
        .background(Color.Nomad.warmCard)
        .cornerRadius(12)
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        switch handleState {
        case .idle:
            EmptyView()
        case .checking:
            ProgressView()
                .tint(Color.Nomad.globeBackground.opacity(0.5))
                .scaleEffect(0.8)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color.Nomad.amber)
        case .taken:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(Color.Nomad.destructive)
        case .invalidFormat:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Color.Nomad.destructive)
        }
    }

    @ViewBuilder
    private var validationCaption: some View {
        switch handleState {
        case .available:
            Text("Available")
                .font(AppFont.caption())
                .foregroundColor(Color.Nomad.amber)
        case .taken:
            Text("Already taken")
                .font(AppFont.caption())
                .foregroundColor(Color.Nomad.destructive)
        case .invalidFormat:
            Text("Letters, numbers, and underscores only")
                .font(AppFont.caption())
                .foregroundColor(Color.Nomad.destructive)
        default:
            EmptyView()
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        let isDisabled = handleState != .available || isSubmitting

        return Button {
            Task { await submitHandle() }
        } label: {
            ZStack {
                if isSubmitting {
                    ProgressView()
                        .tint(Color.Nomad.globeBackground)
                } else {
                    Text("Continue")
                        .font(AppFont.buttonLabel())
                        .foregroundColor(Color.Nomad.globeBackground)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.Nomad.amber.opacity(isDisabled ? 0.5 : 1.0))
            .cornerRadius(12)
        }
        .disabled(isDisabled)
    }

    // MARK: - Debounced validation

    private func onHandleTextChanged(_ newValue: String) {
        // T-02-07: Strip invalid characters, enforce lowercase, limit to 30 chars
        let filtered = String(
            newValue
                .lowercased()
                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                .prefix(30)
        )
        if filtered != newValue {
            handleText = filtered
            return
        }

        submitError = nil

        if filtered.isEmpty {
            handleState = .idle
            debounceTask?.cancel()
            return
        }

        handleState = .checking
        debounceTask?.cancel()
        debounceTask = Task {
            do {
                // T-02-10: 500ms debounce reduces Firestore read volume
                try await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                let available = await userService.isHandleAvailable(filtered)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    handleState = available ? .available : .taken
                }
            } catch {
                // Task was cancelled — no-op
            }
        }
    }

    // MARK: - Submit

    private func submitHandle() async {
        guard case .authenticated(let user) = authManager.authState else { return }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            try await userService.createUserWithHandle(
                uid: user.uid,
                handle: handleText,
                email: coordinator.email
            )
            coordinator.handle = handleText
            coordinator.advance()
        } catch {
            submitError = "Couldn't save your handle. Tap to retry."
        }
    }
}
