import SwiftUI

struct CheckEmailView: View {
    @Environment(AuthService.self) private var authService

    let email: String

    @State private var resentJustNow = false

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "envelope.badge")
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.accent)

            Text("Check Your Email")
                .font(Theme.Typography.title)

            VStack(spacing: Theme.Spacing.xs) {
                Text("We sent a confirmation link to")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Text(email)
                    .font(Theme.Typography.headline)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.xl)

            Text("Tap the link in the email to finish setting up your account. You'll be brought back here automatically.")
                .font(Theme.Typography.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)

            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                Button(action: resend) {
                    if authService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 24)
                    } else if resentJustNow {
                        Label("Email sent", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 24)
                    } else {
                        Text("Resend Email")
                            .frame(maxWidth: .infinity, minHeight: 24)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(authService.isLoading || resentJustNow)

                Button("Use a Different Email") {
                    authService.cancelPendingConfirmation()
                }
                .font(.subheadline)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            if let error = authService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            Spacer()
        }
    }

    private func resend() {
        Task {
            await authService.resendConfirmationEmail(email)
            if authService.error == nil {
                resentJustNow = true
                try? await Task.sleep(for: .seconds(3))
                resentJustNow = false
            }
        }
    }
}
