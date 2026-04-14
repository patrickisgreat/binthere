import Foundation
import Supabase

@Observable
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    var isAuthenticated: Bool {
        currentUserId != nil
    }

    var currentUserId: String?

    private init() {
        if SupabaseConfig.isConfigured,
           let url = URL(string: SupabaseConfig.url) {
            client = SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.anonKey)
        } else {
            // Fallback for development without Supabase configured
            // swiftlint:disable:next force_unwrapping
            let placeholderURL = URL(string: "https://placeholder.supabase.co")!
            client = SupabaseClient(supabaseURL: placeholderURL, supabaseKey: "placeholder")
            print("[SupabaseManager] Not configured. URL: '\(SupabaseConfig.url)' Key: '\(SupabaseConfig.anonKey.prefix(10))...'")
        }
    }

    func refreshAuthState() async {
        do {
            let session = try await client.auth.session
            currentUserId = session.user.id.uuidString
        } catch {
            currentUserId = nil
        }
    }
}
