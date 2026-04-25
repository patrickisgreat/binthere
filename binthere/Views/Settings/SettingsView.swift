import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(HouseholdService.self) private var householdService
    @Environment(SyncService.self) private var syncService
    @State private var apiKey = ""
    @State private var showingAPIKey = false
    @State private var selectedProvider: AIProvider = .anthropic
    @State private var isSavingAIConfig = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var notificationsEnabled = false
    @State private var showingInvite = false
    @State private var dailyOverdueCheck = false

    private var canEditAIConfig: Bool {
        guard let userId = authService.currentUserId else { return false }
        return householdService.isOwner(userId: userId)
    }

    private var storedAPIKey: String {
        householdService.currentHousehold?.apiKey ?? ""
    }

    private var storedProvider: AIProvider {
        guard let raw = householdService.currentHousehold?.aiProvider,
              let provider = AIProvider(rawValue: raw) else {
            return .anthropic
        }
        return provider
    }

    private var hasUnsavedAIChanges: Bool {
        apiKey != storedAPIKey || selectedProvider != storedProvider
    }

    var body: some View {
        Form {
            Section("Account") {
                if let email = authService.currentEmail {
                    LabeledContent("Email", value: email)
                }
                Button(role: .destructive) {
                    Task { await authService.signOut() }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section {
                Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                    Label("Delete Account", systemImage: "trash")
                }

                if let deleteError {
                    Text(deleteError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("This permanently deletes your account and all associated data. This cannot be undone.")
            }

            Section("Space") {
                if let household = householdService.currentHousehold {
                    NavigationLink {
                        HouseholdView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(household.name)
                                HStack(spacing: 6) {
                                    Text(household.spaceTypeInfo.displayName)
                                    Text("·")
                                    Text("\(householdService.members.count) members")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: household.spaceTypeInfo.icon)
                        }
                    }
                    Button(action: { showingInvite = true }) {
                        Label("Invite Someone", systemImage: "person.badge.plus")
                    }
                } else {
                    Text("No space")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Sync") {
                HStack {
                    Label {
                        Text(syncService.syncStatus.rawValue)
                    } icon: {
                        switch syncService.syncStatus {
                        case .syncing:
                            ProgressView()
                                .scaleEffect(0.7)
                        case .synced:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .offline:
                            Image(systemName: "wifi.slash")
                                .foregroundStyle(.orange)
                        case .error:
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        case .idle:
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let lastSync = syncService.lastSyncedAt {
                        Text(lastSync, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: syncNow) {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(syncService.isSyncing)

                if let error = syncService.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Reports & Export") {
                NavigationLink {
                    ReportsView()
                } label: {
                    Label("Reports & Analytics", systemImage: "chart.bar.doc.horizontal")
                }
            }

            Section("Notifications") {
                Toggle("Due-back reminders", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if enabled {
                            Task { _ = await NotificationService.requestPermission() }
                        }
                    }

                Toggle("Daily overdue check (9 AM)", isOn: $dailyOverdueCheck)
                    .onChange(of: dailyOverdueCheck) { _, enabled in
                        if enabled {
                            NotificationService.scheduleDailyOverdueCheck()
                        } else {
                            UNUserNotificationCenter.current()
                                .removePendingNotificationRequests(withIdentifiers: ["daily_overdue_check"])
                        }
                    }

                Text("Get notified when items are due back or overdue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("AI Provider", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .disabled(!canEditAIConfig || isSavingAIConfig)

                HStack {
                    if showingAPIKey {
                        TextField(apiKeyPlaceholder, text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .disabled(!canEditAIConfig || isSavingAIConfig)
                    } else {
                        SecureField(apiKeyPlaceholder, text: $apiKey)
                            .disabled(!canEditAIConfig || isSavingAIConfig)
                    }
                    Button(action: { showingAPIKey.toggle() }) {
                        Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if canEditAIConfig {
                    Button(action: saveAIConfig) {
                        if isSavingAIConfig {
                            ProgressView()
                        } else {
                            Label("Save", systemImage: "checkmark.circle")
                        }
                    }
                    .disabled(!hasUnsavedAIChanges || isSavingAIConfig)
                }
            } header: {
                Text("AI Analysis")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(apiKeyHelpText)
                    Text(aiConfigScopeText)
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Built with", value: "SwiftUI + SwiftData")
            }
        }
        .navigationTitle("Settings")
        .task {
            syncAIConfigFromHousehold()
        }
        .onChange(of: householdService.currentHousehold?.apiKey) { _, _ in
            syncAIConfigFromHousehold()
        }
        .onChange(of: householdService.currentHousehold?.aiProvider) { _, _ in
            syncAIConfigFromHousehold()
        }
        .sheet(isPresented: $showingInvite) {
            InviteMemberSheet()
        }
        .alert("Delete Account?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Everything", role: .destructive) {
                Task {
                    do {
                        try await authService.deleteAccount()
                        wipeLocalData()
                    } catch {
                        deleteError = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete your account, all your bins, items, and data. This action cannot be undone.")
        }
    }

    private var apiKeyPlaceholder: String {
        selectedProvider == .openai ? "OpenAI API Key" : "Claude API Key"
    }

    private var apiKeyHelpText: String {
        switch selectedProvider {
        case .anthropic:
            return "Get a key at console.anthropic.com"
        case .openai:
            return "Get a key at platform.openai.com/api-keys"
        }
    }

    private var aiConfigScopeText: String {
        if canEditAIConfig {
            return "Shared by everyone in your space. Only owners can change it."
        }
        return "Set by the space owner and shared with all members."
    }

    private func syncAIConfigFromHousehold() {
        apiKey = storedAPIKey
        selectedProvider = storedProvider
    }

    private func saveAIConfig() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyToSave = trimmed.isEmpty ? nil : trimmed
        isSavingAIConfig = true
        Task {
            await householdService.updateAIConfig(apiKey: keyToSave, provider: selectedProvider)
            syncAIConfigFromHousehold()
            isSavingAIConfig = false
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func wipeLocalData() {
        try? modelContext.delete(model: CustomAttribute.self)
        try? modelContext.delete(model: CheckoutRecord.self)
        try? modelContext.delete(model: Item.self)
        try? modelContext.delete(model: Bin.self)
        try? modelContext.delete(model: Zone.self)
        try? modelContext.save()
    }

    private func syncNow() {
        let householdId = householdService.currentHouseholdId
        guard !householdId.isEmpty else { return }
        Task {
            await syncService.syncAll(householdId: householdId)
        }
    }
}
