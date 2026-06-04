import Foundation
import SwiftData

/// Local-only stand-in for the former Supabase sync service (PR 1 of the
/// CloudKit/SQLiteData migration). All remote networking is removed; the
/// app now operates purely against the on-device SwiftData store. The
/// public surface (status flags, delete helpers, push/sync entry points) is
/// preserved so existing call sites keep compiling. The push/sync methods
/// are inert no-ops — real synchronization returns via SQLiteData's
/// SyncEngine in PR 2.
@Observable
final class SyncService {
    var isSyncing = false
    var lastSyncedAt: Date?
    var error: String?
    var isOnline = true
    var syncStatus: SyncStatus = .idle

    enum SyncStatus: String {
        case idle = "Idle"
        case syncing = "Syncing..."
        case synced = "Synced"
        case offline = "Offline"
        case error = "Error"
    }

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Local Deletes
    //
    // These remain real: they delete from the on-device store. SwiftData's
    // cascade rules handle child cleanup (items under a bin, etc.).

    @MainActor
    func deleteBin(_ bin: Bin) async {
        modelContext?.delete(bin)
        try? modelContext?.save()
    }

    @MainActor
    func deleteItem(_ item: Item) async {
        modelContext?.delete(item)
        try? modelContext?.save()
    }

    @MainActor
    func deleteZone(_ zone: Zone) async {
        modelContext?.delete(zone)
        try? modelContext?.save()
    }

    /// Nothing is tombstoned in local-only mode — there is no remote pull
    /// that could re-insert a locally deleted record.
    func isTombstoned(_ id: UUID) -> Bool { false }

    // MARK: - Sync entry points (inert until SQLiteData SyncEngine)

    func syncAll(householdId: String) async {
        syncStatus = .idle
    }

    func pushAllDirty(householdId: String) async throws {}

    func subscribeToChanges(householdId: String) async {}

    func unsubscribe() async {}

    func pushZone(_ zone: Zone, householdId: String) async throws {}

    func pushBin(_ bin: Bin, householdId: String) async throws {}

    func pushItem(_ item: Item, householdId: String) async throws {}

    func pushCheckoutRecord(_ record: CheckoutRecord, householdId: String) async throws {}
}
