import AuthenticationServices
import Foundation

/// Local-only identity for the post-Supabase transition (PR 1 of the
/// CloudKit/SQLiteData migration). There is no remote auth anymore: the
/// app runs against the on-device store and treats the device as a single
/// signed-in local user. Sign-in screens are bypassed because
/// `isAuthenticated` is always true. The remote-auth surface is preserved
/// as no-ops only so existing call sites keep compiling until the CloudKit
/// (Sign in with Apple) identity lands in a later PR.
@Observable
final class AuthService {
    var currentUserId: String?
    var currentEmail: String?
    var isLoading = false
    var error: String?

    var isAuthenticated: Bool { currentUserId != nil }

    private static let localUserIdKey = "local_user_id"

    init() {
        currentUserId = Self.localUserId()
    }

    /// A stable per-device user id, persisted so records created across
    /// launches keep a consistent owner reference.
    private static func localUserId() -> String {
        if let existing = UserDefaults.standard.string(forKey: localUserIdKey) {
            return existing
        }
        let new = UUID().uuidString.lowercased()
        UserDefaults.standard.set(new, forKey: localUserIdKey)
        return new
    }

    // MARK: - Session (no-ops in local mode)

    func startObservingAuthState() {
        currentUserId = Self.localUserId()
    }

    func restoreSession() async {
        currentUserId = Self.localUserId()
    }

    // MARK: - Sign-in surface (retained for compile compatibility)

    func signUpWithEmail(email: String, password: String) async {
        currentUserId = Self.localUserId()
        currentEmail = email
    }

    func signInWithEmail(email: String, password: String) async {
        currentUserId = Self.localUserId()
        currentEmail = email
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        currentUserId = Self.localUserId()
        currentEmail = credential.email ?? currentEmail
    }

    func signInWithGoogle() async {
        currentUserId = Self.localUserId()
    }

    // MARK: - Sign Out

    func signOut() async {
        currentEmail = nil
        // Local user id persists; the device remains its own local account.
    }

    // MARK: - Delete Account

    /// Clears the local identity. The actual on-device data wipe is handled
    /// by the caller (SettingsView) after this returns.
    func deleteAccount() async throws {
        UserDefaults.standard.removeObject(forKey: Self.localUserIdKey)
        currentUserId = nil
        currentEmail = nil
    }
}
