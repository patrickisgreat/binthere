import SwiftUI

struct SignUpView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    private var isValid: Bool {
        !email.isEmpty && password.count >= 6 && passwordsMatch
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Create Account")
                    .font(.title2.weight(.bold))

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    SecureField("Password (6+ characters)", text: $password)
                        .textContentType(.newPassword)
                        .padding()
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding()
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Passwords don't match")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 40)

                Button(action: signUp) {
                    if authService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 20)
                    } else {
                        Text("Create Account")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 20)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || authService.isLoading)
                .padding(.horizontal, 40)

                if let error = authService.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func signUp() {
        Task {
            await authService.signUpWithEmail(email: email, password: password)
            if authService.isAuthenticated {
                dismiss()
            }
        }
    }
}
