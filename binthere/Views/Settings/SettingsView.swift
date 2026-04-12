import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @State private var apiKey = ImageAnalysisService.apiKey ?? ""
    @State private var showingAPIKey = false

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
    }
}
