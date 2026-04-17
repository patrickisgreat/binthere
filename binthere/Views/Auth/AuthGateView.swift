import SwiftUI
import SwiftData

struct AuthGateView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authService = AuthService()
    @State private var syncService = SyncService()
    @State private var householdService = HouseholdService()
    @State private var hasCheckedSession = false
    @State private var showingOnboarding = false

    private var hasCompletedOnboarding: Bool {
        guard let userId = authService.currentUserId else { return true }
        return UserDefaults.standard.bool(forKey: "onboarding_complete_\(userId)")
    }

    private func completeOnboarding() {
        if let userId = authService.currentUserId {
            UserDefaults.standard.set(true, forKey: "onboarding_complete_\(userId)")
        }
        showingOnboarding = false
    }

    var body: some View {
        Group {
            if !hasCheckedSession {
                ProgressView("Loading...")
            } else if !authService.isAuthenticated {
                SignInView()
            } else if householdService.currentHousehold == nil && !householdService.isLoading {
                HouseholdSetupView()
            } else if householdService.currentHousehold != nil && showingOnboarding {
                OnboardingView(onComplete: completeOnboarding)
            } else if householdService.currentHousehold != nil {
                MainTabView()
            } else {
                ProgressView("Loading...")
            }
        }
        .environment(authService)
        .environment(syncService)
        .environment(householdService)
        .task {
            authService.startObservingAuthState()
            await authService.restoreSession()
            syncService.configure(modelContext: modelContext)
            _ = await NotificationService.requestPermission()
            NotificationService.registerCategories()
            hasCheckedSession = true
            if let userId = authService.currentUserId {
                await householdService.loadHousehold(userId: userId)
                if !householdService.currentHouseholdId.isEmpty {
                    await syncService.syncAll(householdId: householdService.currentHouseholdId)
                }
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth, let userId = authService.currentUserId {
                Task {
                    await householdService.loadHousehold(userId: userId)
                }
            } else {
                Task { await syncService.unsubscribe() }
            }
        }
        .onChange(of: householdService.currentHouseholdId) { _, newId in
            if !newId.isEmpty {
                if !hasCompletedOnboarding {
                    showingOnboarding = true
                }
                Task {
                    await syncService.syncAll(householdId: newId)
                    await syncService.subscribeToChanges(householdId: newId)
                }
            }
        }
    }
}
