import SwiftUI

struct JoinHouseholdView: View {
    @Environment(AuthService.self) private var authService
    @Environment(HouseholdService.self) private var householdService
    @Environment(\.dismiss) private var dismiss

    @State private var inviteCode = ""
    @State private var displayName = ""
    @State private var isJoining = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "house.and.flag")
                    .font(.system(size: 60))
                    .foregroundStyle(.green.opacity(0.6))

                Text("Join a Household")
                    .font(.title2.weight(.semibold))

                Text("Enter the invite code someone shared with you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                VStack(spacing: 12) {
                    TextField("Invite Code", text: $inviteCode)
                        .font(.title3.monospaced())
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    TextField("Your Name", text: $displayName)
                        .textContentType(.name)
                        .padding()
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 40)

                Button(action: joinHousehold) {
                    if isJoining {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 20)
                    } else {
                        Text("Join")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 20)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inviteCode.isEmpty || displayName.isEmpty || isJoining)
                .padding(.horizontal, 40)

                if let error = householdService.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func joinHousehold() {
        guard let userId = authService.currentUserId else { return }
        isJoining = true
        Task {
            let success = await householdService.joinHousehold(
                inviteCode: inviteCode,
                userId: userId,
                displayName: displayName
            )
            isJoining = false
            if success { dismiss() }
        }
    }
}
