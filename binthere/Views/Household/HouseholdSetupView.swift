import SwiftUI

struct HouseholdSetupView: View {
    @Environment(AuthService.self) private var authService
    @Environment(HouseholdService.self) private var householdService

    @State private var spaceName = ""
    @State private var displayName = ""
    @State private var selectedType: SpaceType = .home
    @State private var showingJoin = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: selectedType.icon)
                .font(.system(size: 60))
                .foregroundStyle(.blue.opacity(0.6))

            Text("Create Your Space")
                .font(.title2.weight(.bold))

            Text("Set up a space to start organizing your bins, or join an existing one with an invite code.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                // Space type picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SpaceType.allCases) { type in
                            SpaceTypeCard(
                                type: type,
                                isSelected: selectedType == type
                            ) {
                                selectedType = type
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.horizontal, -40)

                TextField(namePlaceholder, text: $spaceName)
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                TextField("Your Name", text: $displayName)
                    .textContentType(.name)
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button(action: createSpace) {
                    if householdService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 20)
                    } else {
                        Text("Create Space")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 20)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(spaceName.isEmpty || displayName.isEmpty || householdService.isLoading)
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

    private var namePlaceholder: String {
        switch selectedType {
        case .home: return "Space Name (e.g. The Bennetts)"
        case .warehouse: return "Warehouse Name"
        case .office: return "Office Name"
        case .studio: return "Studio Name"
        case .storageUnit: return "Storage Unit Name"
        case .custom: return "Space Name"
        }
    }

    private func createSpace() {
        guard let userId = authService.currentUserId else { return }
        Task {
            await householdService.createHousehold(
                name: spaceName,
                spaceType: selectedType,
                userId: userId,
                displayName: displayName
            )
        }
    }
}

private struct SpaceTypeCard: View {
    let type: SpaceType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.title3)
                Text(type.displayName)
                    .font(.caption2.weight(.medium))
            }
            .frame(width: 72, height: 64)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
