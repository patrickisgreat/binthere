import SwiftUI

struct InviteMemberSheet: View {
    @Environment(HouseholdService.self) private var householdService
    @Environment(\.dismiss) private var dismiss

    @State private var generatedCode: String?
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.opacity(0.6))

                Text("Invite Someone")
                    .font(.title2.weight(.semibold))

                Text("Generate a code and share it. They'll enter it in the app to join your household.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if let code = generatedCode {
                    Text(code)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .padding()
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .textSelection(.enabled)

                    Text("Code expires in 7 days")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ShareLink(item: "Join my binthere household with code: \(code)") {
                        Label("Share Code", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 40)
                } else {
                    Button(action: generateCode) {
                        if isGenerating {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 20)
                        } else {
                            Text("Generate Invite Code")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 20)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating)
                    .padding(.horizontal, 40)
                }

                if let error = householdService.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func generateCode() {
        isGenerating = true
        Task {
            generatedCode = await householdService.generateInviteCode()
            isGenerating = false
        }
    }
}
