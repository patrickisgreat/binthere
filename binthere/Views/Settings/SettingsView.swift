import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(HouseholdService.self) private var householdService
    @Environment(SyncService.self) private var syncService
    @State private var apiKey = ImageAnalysisService.apiKey ?? ""
    @State private var showingAPIKey = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var notificationsEnabled = false
    @State private var showingInvite = false
    @State private var dailyOverdueCheck = false

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

            Section("Household") {
                if let household = householdService.currentHousehold {
                    NavigationLink {
                        HouseholdView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(household.name)
                                Text("\(householdService.members.count) members")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "house")
                        }
                    }
                    Button(action: { showingInvite = true }) {
                        Label("Invite Someone", systemImage: "person.badge.plus")
                    }
                } else {
                    Text("No household")
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

            Section("AI Analysis") {
                HStack {
                    if showingAPIKey {
                        TextField("Claude API Key", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("Claude API Key", text: $apiKey)
                    }
                    Button(action: { showingAPIKey.toggle() }) {
                        Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .onChange(of: apiKey) { _, newValue in
                    ImageAnalysisService.apiKey = newValue.isEmpty ? nil : newValue
                }

                Text("Required for AI-powered item detection. Get a key at console.anthropic.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Built with", value: "SwiftUI + SwiftData")
            }
        }
        .navigationTitle("Settings")
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
