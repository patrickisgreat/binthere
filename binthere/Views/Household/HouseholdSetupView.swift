import SwiftUI

struct HouseholdSetupView: View {
    @Environment(AuthService.self) private var authService
    @Environment(HouseholdService.self) private var householdService

    @State private var householdName = ""
    @State private var displayName = ""
    @State private var showingJoin = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "house")
                .font(.system(size: 60))
                .foregroundStyle(.blue.opacity(0.6))

            Text("Set Up Your Household")
                .font(.title2.weight(.bold))

            Text("Create a household to start organizing your bins, or join an existing one with an invite code.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                TextField("Household Name (e.g. The Bennetts)", text: $householdName)
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                TextField("Your Name", text: $displayName)
                    .textContentType(.name)
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button(action: createHousehold) {
                    if householdService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 20)
                    } else {
                        Text("Create Household")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 20)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(householdName.isEmpty || displayName.isEmpty || householdService.isLoading)
            }
            .padding(.horizontal, 40)

            HStack {
                Rectangle().fill(.quaternary).frame(height: 1)
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle().fill(.quaternary).frame(height: 1)
            }
            .padding(.horizontal, 40)

            Button("Join with Invite Code") {
                showingJoin = true
            }
            .font(.subheadline)

            if let error = householdService.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .sheet(isPresented: $showingJoin) {
            JoinHouseholdView()
        }
    }

    private func createHousehold() {
        guard let userId = authService.currentUserId else { return }
        Task {
            await householdService.createHousehold(
                name: householdName,
                userId: userId,
                displayName: displayName
            )
        }
    }
}
