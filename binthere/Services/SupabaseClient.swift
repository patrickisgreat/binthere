import Foundation
import Supabase

@Observable
final class SupabaseManager {
    static let shared = SupabaseManager()

    // Use the global supabase client from SupabaseConfig.swift
    let client: SupabaseClient = supabase

    var isAuthenticated: Bool {
        currentUserId != nil
    }

    var currentUserId: String?

    private init() {}

    func refreshAuthState() async {
        do {
            let session = try await client.auth.session
            currentUserId = session.user.id.uuidString
        } catch {
            currentUserId = nil
        }
    }
}
