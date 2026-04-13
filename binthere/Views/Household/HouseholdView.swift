import SwiftUI

struct HouseholdView: View {
    @Environment(AuthService.self) private var authService
    @Environment(HouseholdService.self) private var householdService

    @State private var showingInvite = false

    var body: some View {
        List {
            if let household = householdService.currentHousehold {
                Section("Household") {
                    LabeledContent("Name", value: household.name)
                    LabeledContent("Members", value: "\(householdService.members.count)")
                }

                Section("Members") {
                    ForEach(householdService.members) { member in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.displayName.isEmpty ? "Member" : member.displayName)
                                    .font(.headline)
                                Text(member.role.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(roleColor(member.role))
                            }

                            Spacer()

                            if member.userId.uuidString == authService.currentUserId {
                                Text("You")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            if canManageMembers,
                               member.userId.uuidString != authService.currentUserId {
                                Button(role: .destructive) {
                                    Task { await householdService.removeMember(memberId: member.id) }
                                } label: {
                                    Label("Remove", systemImage: "person.badge.minus")
                                }
                            }
                        }
                    }
                }

                if !householdService.pendingInvitations.isEmpty {
                    Section("Pending Invitations") {
                        ForEach(householdService.pendingInvitations) { invitation in
                            HStack {
                                Text(invitation.inviteCode)
                                    .font(.headline.monospaced())
                                Spacer()
                                Text("Expires \(invitation.expiresAt, style: .relative)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if canManageMembers {
                    Section {
                        Button(action: { showingInvite = true }) {
                            Label("Invite Member", systemImage: "person.badge.plus")
                        }
                    }
                }
            }
        }
        .navigationTitle("Household")
        .sheet(isPresented: $showingInvite) {
            InviteMemberSheet()
        }
        .task {
            await householdService.loadMembers()
            await householdService.loadInvitations()
        }
    }

    private var canManageMembers: Bool {
        guard let userId = authService.currentUserId else { return false }
        return householdService.members.contains {
            $0.userId.uuidString == userId && ($0.role == "owner" || $0.role == "admin")
        }
    }

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "owner": .orange
        case "admin": .blue
        default: .secondary
        }
    }
}
