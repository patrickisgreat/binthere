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
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let anonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !urlString.contains("YOUR_PROJECT") else {
            // Fallback for development without Supabase configured
            // swiftlint:disable:next force_unwrapping
            let placeholderURL = URL(string: "https://placeholder.supabase.co")!
            client = SupabaseClient(supabaseURL: placeholderURL, supabaseKey: "placeholder")
            return
        }

        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
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
