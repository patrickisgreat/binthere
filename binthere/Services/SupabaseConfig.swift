import Foundation
import Supabase

// Supabase client — initialized once, used everywhere.
// Credentials are from Settings > API Keys in your Supabase dashboard.
//
// This file is NOT git-ignored because the publishable key is safe
// for client-side use (RLS protects the data). It's equivalent to
// a Firebase config file.

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://graxolpusjcqlzikbnpr.supabase.co")!,
    supabaseKey: "sb_publishable_1O3xXBqBCO-g_-gdgyFUSA_UmSpp7RJ"
)
