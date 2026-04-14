import Foundation
import Supabase

// Supabase client — initialized once, used everywhere.
// Credentials are from Settings > API Keys in your Supabase dashboard.
//
// This file is NOT git-ignored because the publishable key is safe
// for client-side use (RLS protects the data). It's equivalent to
// a Firebase config file.

// swiftlint:disable force_unwrapping
private let supabaseURL = URL(string: "https://graxolpusjcqlzikbnpr.supabase.co")!
private let authCallbackURL = URL(string: "beeBetter.binthere://auth-callback")!
// swiftlint:enable force_unwrapping

let supabase = SupabaseClient(
    supabaseURL: supabaseURL,
    supabaseKey: "sb_publishable_1O3xXBqBCO-g_-gdgyFUSA_UmSpp7RJ",
    options: .init(
        auth: .init(
            redirectToURL: authCallbackURL
        )
    )
)
