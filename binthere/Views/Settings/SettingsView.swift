import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @Environment(HouseholdService.self) private var householdService
    @State private var apiKey = ImageAnalysisService.apiKey ?? ""
    @State private var showingAPIKey = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteError: String?

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
                } else {
                    Text("No household")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Reports & Export") {
                NavigationLink {
                    ReportsView()
                } label: {
                    Label("Reports & Analytics", systemImage: "chart.bar.doc.horizontal")
                }
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
        .alert("Delete Account?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Everything", role: .destructive) {
                Task {
                    do {
                        try await authService.deleteAccount()
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
}
