import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) private var authService
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo
            VStack(spacing: 8) {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                Text("binthere")
                    .font(.largeTitle.weight(.bold))
                Text("Know where your stuff is.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 40)

            // Divider
            HStack {
                Rectangle().fill(.quaternary).frame(height: 1)
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle().fill(.quaternary).frame(height: 1)
            }
            .padding(.horizontal, 40)

            // Email/password
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button(action: signInWithEmail) {
                    if authService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 20)
                    } else {
                        Text("Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 20)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || authService.isLoading)

                Button("Don't have an account? Sign up") {
                    showingSignUp = true
                }
                .font(.subheadline)
            }
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
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
        }
    }

    private func signInWithEmail() {
        Task {
            await authService.signInWithEmail(email: email, password: password)
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            Task {
                await authService.signInWithApple(credential: credential)
            }
        case .failure(let error):
            authService.error = error.localizedDescription
        }
    }
}
