import Foundation

struct Household: Codable, Identifiable {
    let id: UUID
    let name: String
    let spaceType: String
    let createdBy: UUID
    let createdAt: Date
    let aiProvider: String?
    let apiKey: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case spaceType = "space_type"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case aiProvider = "ai_provider"
        case apiKey = "api_key"
    }

    var spaceTypeInfo: SpaceType {
        SpaceType(rawValue: spaceType) ?? .home
    }

    /// Returns a copy with updated AI config, preserving every other field.
    func withAIConfig(apiKey: String?, provider: String) -> Self {
        Self(
            id: id, name: name, spaceType: spaceType, createdBy: createdBy,
            createdAt: createdAt, aiProvider: provider, apiKey: apiKey
        )
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

/// Local-only household management for the post-Supabase transition
/// (PR 1 of the CloudKit/SQLiteData migration). A "household" is a single
/// on-device space persisted in UserDefaults; there is no remote membership
/// yet. The household-wide AI key/provider (from the shared-key feature)
/// still works — it's now stored locally on the household. Cross-person
/// sharing returns via CKShare in a later PR, so `generateInviteCode`/
/// `joinHousehold` are intentionally inert until then.
@Observable
final class HouseholdService {
    var currentHousehold: Household? {
        didSet {
            ImageAnalysisService.setCurrentHousehold(currentHousehold)
        }
    }
    var members: [HouseholdMember] = []
    var pendingInvitations: [Invitation] = []
    var isLoading = false
    var error: String?

    private static let storedHouseholdKey = "local_household"
    private static let storedDisplayNameKey = "local_household_display_name"

    var currentHouseholdId: String {
        currentHousehold?.id.uuidString.lowercased() ?? ""
    }

    /// True when `userId` is the owner of the current local household.
    func isOwner(userId: String) -> Bool {
        members.contains { member in
            member.role == "owner"
                && member.userId.uuidString.lowercased() == userId.lowercased()
        }
    }

    // MARK: - Load

    func loadHousehold(userId: String) async {
        guard let household = Self.loadStoredHousehold() else {
            // No space yet — the user is prompted to create one.
            currentHousehold = nil
            members = []
            return
        }
        currentHousehold = household
        rebuildLocalMembership(userId: userId, household: household)
    }

    // MARK: - Create

    func createHousehold(name: String, spaceType: SpaceType = .home,
                         userId: String, displayName: String) async {
        let household = Household(
            id: UUID(),
            name: name,
            spaceType: spaceType.rawValue,
            createdBy: UUID(uuidString: userId) ?? UUID(),
            createdAt: Date(),
            aiProvider: nil,
            apiKey: nil
        )
        Self.store(household: household, displayName: displayName)
        currentHousehold = household
        rebuildLocalMembership(userId: userId, household: household)
        await migrateLegacyAPIKeyIfNeeded(userId: userId)
    }

    /// Moves a pre-existing per-user API key from UserDefaults onto the
    /// local household the first time it's created after upgrade.
    private func migrateLegacyAPIKeyIfNeeded(userId: String) async {
        guard let household = currentHousehold,
              household.apiKey == nil,
              isOwner(userId: userId),
              let legacy = ImageAnalysisService.legacyLocalAPIKey() else { return }

        let provider = AIProvider(rawValue: legacy.provider) ?? .anthropic
        await updateAIConfig(apiKey: legacy.apiKey, provider: provider)

        if currentHousehold?.apiKey == legacy.apiKey {
            ImageAnalysisService.clearLegacyLocalAPIKey()
        }
    }

    // MARK: - AI Config

    /// Updates the household-wide AI provider/key, persisted locally.
    func updateAIConfig(apiKey: String?, provider: AIProvider) async {
        guard let household = currentHousehold else {
            error = "No household loaded."
            return
        }
        let updated = household.withAIConfig(apiKey: apiKey, provider: provider.rawValue)
        Self.store(household: updated,
                   displayName: UserDefaults.standard.string(forKey: Self.storedDisplayNameKey) ?? "You")
        currentHousehold = updated
    }

    func refreshCurrentHousehold() async {
        if let household = Self.loadStoredHousehold() {
            currentHousehold = household
        }
    }

    // MARK: - Members

    func loadMembers() async {
        guard let household = currentHousehold else { return }
        rebuildLocalMembership(userId: household.createdBy.uuidString, household: household)
    }

    func updateMemberRole(memberId: UUID, role: String) async {
        // No-op: single local member until CKShare sharing lands.
    }

    func removeMember(memberId: UUID) async {
        // No-op: single local member until CKShare sharing lands.
    }

    // MARK: - Invitations (inert until CKShare sharing)

    func loadInvitations() async {
        pendingInvitations = []
    }

    func generateInviteCode() async -> String? {
        error = "Sharing isn't available yet."
        return nil
    }

    func joinHousehold(inviteCode: String, userId: String, displayName: String) async -> Bool {
        error = "Sharing isn't available yet."
        return false
    }

    // MARK: - Local persistence helpers

    private func rebuildLocalMembership(userId: String, household: Household) {
        let displayName = UserDefaults.standard.string(forKey: Self.storedDisplayNameKey) ?? "You"
        members = [
            HouseholdMember(
                id: UUID(),
                householdId: household.id,
                userId: UUID(uuidString: userId) ?? household.createdBy,
                role: "owner",
                displayName: displayName,
                joinedAt: household.createdAt
            ),
        ]
        pendingInvitations = []
    }

    private static func loadStoredHousehold() -> Household? {
        guard let data = UserDefaults.standard.data(forKey: storedHouseholdKey) else { return nil }
        return try? JSONDecoder().decode(Household.self, from: data)
    }

    private static func store(household: Household, displayName: String) {
        if let data = try? JSONEncoder().encode(household) {
            UserDefaults.standard.set(data, forKey: storedHouseholdKey)
        }
        UserDefaults.standard.set(displayName, forKey: storedDisplayNameKey)
    }
}
