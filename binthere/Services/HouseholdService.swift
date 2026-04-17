import Foundation
import Supabase

struct Household: Codable, Identifiable {
    let id: UUID
    let name: String
    let spaceType: String
    let createdBy: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case spaceType = "space_type"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }

    var spaceTypeInfo: SpaceType {
        SpaceType(rawValue: spaceType) ?? .home
    }
}

enum SpaceType: String, CaseIterable, Identifiable {
    case home
    case warehouse
    case office
    case studio
    case storageUnit = "storage_unit"
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home: return "Home"
        case .warehouse: return "Warehouse"
        case .office: return "Office"
        case .studio: return "Studio"
        case .storageUnit: return "Storage Unit"
        case .custom: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .warehouse: return "building.2.fill"
        case .office: return "building.fill"
        case .studio: return "paintpalette.fill"
        case .storageUnit: return "shippingbox.fill"
        case .custom: return "square.grid.2x2.fill"
        }
    }
}

struct HouseholdMember: Codable, Identifiable {
    let id: UUID
    let householdId: UUID
    let userId: UUID
    let role: String
    let displayName: String
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, role
        case householdId = "household_id"
        case userId = "user_id"
        case displayName = "display_name"
        case joinedAt = "joined_at"
    }
}

struct Invitation: Codable, Identifiable {
    let id: UUID
    let householdId: UUID
    let inviteCode: String
    let status: String
    let createdAt: Date
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status
        case householdId = "household_id"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

@Observable
final class HouseholdService {
    var currentHousehold: Household?
    var members: [HouseholdMember] = []
    var pendingInvitations: [Invitation] = []
    var isLoading = false
    var error: String?

    private var client: SupabaseClient { SupabaseManager.shared.client }

    var currentHouseholdId: String {
        currentHousehold?.id.uuidString.lowercased() ?? ""
    }

    // MARK: - Load Current Household

    func loadHousehold(userId: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Find household membership for this user
            let memberships: [HouseholdMember] = try await client.from("household_members")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            guard let membership = memberships.first else {
                // No household yet — user needs to create or join one
                currentHousehold = nil
                return
            }

            // Fetch the household
            let households: [Household] = try await client.from("households")
                .select()
                .eq("id", value: membership.householdId.uuidString.lowercased())
                .execute()
                .value

            currentHousehold = households.first
            await loadMembers()
            await loadInvitations()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Create Household

    func createHousehold(name: String, spaceType: SpaceType = .home,
                         userId: String, displayName: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let householdId = UUID()

            let householdPayload: [String: AnyJSON] = [
                "id": .string(householdId.uuidString.lowercased()),
                "name": .string(name),
                "space_type": .string(spaceType.rawValue),
                "created_by": .string(userId),
            ]

            try await client.from("households").insert(householdPayload).execute()

            // Add creator as owner
            let memberPayload: [String: AnyJSON] = [
                "household_id": .string(householdId.uuidString.lowercased()),
                "user_id": .string(userId),
                "role": .string("owner"),
                "display_name": .string(displayName),
            ]
            try await client.from("household_members").insert(memberPayload).execute()

            // Reload
            await loadHousehold(userId: userId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Members

    func loadMembers() async {
        guard let householdId = currentHousehold?.id.uuidString else { return }

        do {
            members = try await client.from("household_members")
                .select()
                .eq("household_id", value: householdId)
                .execute()
                .value
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateMemberRole(memberId: UUID, role: String) async {
        do {
            try await client.from("household_members")
                .update(["role": role])
                .eq("id", value: memberId.uuidString)
                .execute()
            await loadMembers()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeMember(memberId: UUID) async {
        do {
            try await client.from("household_members")
                .delete()
                .eq("id", value: memberId.uuidString)
                .execute()
            await loadMembers()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Invitations

    func loadInvitations() async {
        guard let householdId = currentHousehold?.id.uuidString else { return }

        do {
            pendingInvitations = try await client.from("invitations")
                .select()
                .eq("household_id", value: householdId)
                .eq("status", value: "pending")
                .execute()
                .value
        } catch {
            self.error = error.localizedDescription
        }
    }

    func generateInviteCode() async -> String? {
        guard let householdId = currentHousehold?.id.uuidString,
              let userId = try? await client.auth.session.user.id.uuidString else {
            return nil
        }

        let code = CodeGenerator.generateCode(existingCodes: Set(pendingInvitations.map(\.inviteCode)))

        do {
            let payload: [String: AnyJSON] = [
                "household_id": .string(householdId),
                "invited_by": .string(userId),
                "invite_code": .string(code),
            ]
            try await client.from("invitations").insert(payload).execute()
            await loadInvitations()
            return code
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func joinHousehold(inviteCode: String, userId: String, displayName: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Look up the invitation
            let invitations: [Invitation] = try await client.from("invitations")
                .select()
                .eq("invite_code", value: inviteCode.uppercased())
                .eq("status", value: "pending")
                .execute()
                .value

            guard let invitation = invitations.first else {
                error = "Invalid or expired invite code."
                return false
            }

            // Add user as member
            let memberPayload: [String: AnyJSON] = [
                "household_id": .string(invitation.householdId.uuidString),
                "user_id": .string(userId),
                "role": .string("member"),
                "display_name": .string(displayName),
            ]
            try await client.from("household_members").insert(memberPayload).execute()

            // Mark invitation as accepted
            try await client.from("invitations")
                .update(["status": "accepted"])
                .eq("id", value: invitation.id.uuidString)
                .execute()

            // Reload
            await loadHousehold(userId: userId)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
