import AuthenticationServices
import Foundation
import Supabase

@Observable
final class AuthService {
    var currentUserId: String?
    var currentEmail: String?
    var isLoading = false
    var error: String?

    var isAuthenticated: Bool { currentUserId != nil }

    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Session

    func restoreSession() async {
        do {
            let session = try await client.auth.session
            currentUserId = session.user.id.uuidString
            currentEmail = session.user.email
        } catch {
            currentUserId = nil
            currentEmail = nil
        }
    }

    // MARK: - Email Auth

    func signUpWithEmail(email: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await client.auth.signUp(email: email, password: password)
            currentUserId = response.user.id.uuidString
            currentEmail = response.user.email
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let session = try await client.auth.signIn(email: email, password: password)
            currentUserId = session.user.id.uuidString
            currentEmail = session.user.email
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Sign in with Apple

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            error = "Failed to get Apple ID token."
            return
        }

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: tokenString)
            )
            currentUserId = session.user.id.uuidString
            currentEmail = session.user.email
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            // Ignore sign-out errors
        }
        currentUserId = nil
        currentEmail = nil
    }
}
