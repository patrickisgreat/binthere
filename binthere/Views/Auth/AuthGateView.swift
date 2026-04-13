import SwiftUI

struct AuthGateView: View {
    @State private var authService = AuthService()
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
        .task {
            await authService.restoreSession()
            hasCheckedSession = true
        }
    }
}
