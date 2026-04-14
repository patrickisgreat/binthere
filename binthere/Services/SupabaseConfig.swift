import Foundation

// This file is auto-populated from Secrets.xcconfig at build time.
// The values below are injected via build settings in the Xcode project.
// If they show as "$(SUPABASE_URL)" at runtime, the xcconfig isn't linked.

enum SupabaseConfig {
    // These use the Swift compiler flag approach:
    // In Build Settings, add SUPABASE_URL and SUPABASE_ANON_KEY
    // They're read from the generated Info.plist

    static var url: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
    }

    static var anonKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }

    static var isConfigured: Bool {
        let url = self.url
        return !url.isEmpty && !url.contains("YOUR_PROJECT") && !url.contains("$(")
    }
}
