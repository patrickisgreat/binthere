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
        // Try to restore with a timeout so the app doesn't freeze on launch
        do {
            let session = try await withThrowingTaskGroup(of: Session.self) { group in
                group.addTask {
                    try await self.client.auth.session
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(5))
                    throw CancellationError()
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            currentUserId = session.user.id.uuidString.lowercased()
            currentEmail = session.user.email
        } catch {
            currentUserId = nil
            currentEmail = nil

            #if DEBUG
            // Auto-login with test user in debug builds
            await devAutoLogin()
            #endif
        }
    }

    #if DEBUG
    private func devAutoLogin() async {
        do {
            let session = try await client.auth.signIn(
                email: "test@binthere.dev",
                password: "testtest123"
            )
            currentUserId = session.user.id.uuidString.lowercased()
            currentEmail = session.user.email
            print("[AuthService] Dev auto-login successful: \(currentEmail ?? "")")
        } catch {
            print("[AuthService] Dev auto-login failed: \(error.localizedDescription)")
        }
    }
    #endif

    // MARK: - Email Auth

    func signUpWithEmail(email: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await client.auth.signUp(email: email, password: password)
            currentUserId = response.user.id.uuidString.lowercased()
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
            currentUserId = session.user.id.uuidString.lowercased()
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
            currentUserId = session.user.id.uuidString.lowercased()
            currentEmail = session.user.email
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Sign in with Google

    func signInWithGoogle() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await client.auth.signInWithOAuth(provider: .google)
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

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let userId = currentUserId else { return }

        // Delete all user data from Supabase tables via RPC or direct deletes
        // Household memberships, then the user's auth account
        try await client.from("household_members")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // Delete households where user is the sole owner
        let ownedHouseholds = try await client.from("household_members")
            .select("household_id")
            .eq("user_id", value: userId)
            .eq("role", value: "owner")
            .execute()

        // Sign out and clear local state
        try await client.auth.signOut()
        currentUserId = nil
        currentEmail = nil

        // Note: Supabase admin API is needed to fully delete the auth user.
        // For now, the user's data is removed and they're signed out.
        // Set up a Supabase Edge Function or database trigger to cascade-delete
        // the auth.users record when all memberships are removed.
        _ = ownedHouseholds
    }
}
