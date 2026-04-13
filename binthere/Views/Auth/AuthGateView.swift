import SwiftUI
import SwiftData

struct AuthGateView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authService = AuthService()
    @State private var syncService = SyncService()
    @State private var hasCheckedSession = false

    var body: some View {
        Group {
            if !hasCheckedSession {
                ProgressView("Loading...")
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                SignInView()
            }
        }
        .environment(authService)
        .environment(syncService)
        .task {
            await authService.restoreSession()
            hasCheckedSession = true
            syncService.configure(modelContext: modelContext)
        }
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth {
                // Sync on sign-in — for now uses empty householdId
                // Will be populated by HouseholdService in PR D
                Task {
                    await syncService.syncAll(householdId: "")
                }
            }
        }
    }
}
