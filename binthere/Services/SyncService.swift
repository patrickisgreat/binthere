import Foundation
import SwiftData
import Supabase

@Observable
final class SyncService {
    var isSyncing = false
    var lastSyncedAt: Date?
    var error: String?

    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Full Sync

    func syncAll(householdId: String) async {
        guard !isSyncing else { return }
        isSyncing = true
        error = nil
        defer { isSyncing = false }

        do {
            try await pullZones(householdId: householdId)
            try await pullBins(householdId: householdId)
            try await pullItems(householdId: householdId)
            try await pullCheckoutRecords(householdId: householdId)
            try await pullCustomAttributes(householdId: householdId)
            lastSyncedAt = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Push Individual Records

    func pushZone(_ zone: Zone, householdId: String) async throws {
        let payload: [String: AnyJSON] = [
            "id": .string(zone.id.uuidString),
            "household_id": .string(householdId),
            "name": .string(zone.name),
            "location_description": .string(zone.locationDescription),
            "color": .string(zone.color),
            "icon": .string(zone.icon),
        ]
        try await client.from("zones").upsert(payload).execute()
        zone.updatedAt = Date()
    }

    func pushBin(_ bin: Bin, householdId: String) async throws {
        var payload: [String: AnyJSON] = [
            "id": .string(bin.id.uuidString),
            "household_id": .string(householdId),
            "code": .string(bin.code),
            "name": .string(bin.name),
            "bin_description": .string(bin.binDescription),
            "location": .string(bin.location),
            "color": .string(bin.color),
        ]
        if let zoneId = bin.zone?.id {
            payload["zone_id"] = .string(zoneId.uuidString)
        }
        try await client.from("bins").upsert(payload).execute()
        bin.updatedAt = Date()
    }

    func pushItem(_ item: Item, householdId: String) async throws {
        var payload: [String: AnyJSON] = [
            "id": .string(item.id.uuidString),
            "household_id": .string(householdId),
            "name": .string(item.name),
            "item_description": .string(item.itemDescription),
            "color": .string(item.color),
            "notes": .string(item.notes),
            "is_checked_out": .bool(item.isCheckedOut),
            "value_source": .string(item.valueSource),
            "created_by": .string(item.createdBy),
            "checkout_permission": .string(item.checkoutPermission),
            "tags": .array(item.tags.map { .string($0) }),
            "image_paths": .array(item.imagePaths.map { .string($0) }),
            "allowed_checkout_users": .array(item.allowedCheckoutUsers.map { .string($0) }),
        ]
        if let binId = item.bin?.id {
            payload["bin_id"] = .string(binId.uuidString)
        }
        if let value = item.value {
            payload["value"] = .double(value)
        }
        if let maxDays = item.maxCheckoutDays {
            payload["max_checkout_days"] = .integer(maxDays)
        }
        try await client.from("items").upsert(payload).execute()
        item.updatedAt = Date()
    }

    func pushCheckoutRecord(_ record: CheckoutRecord, householdId: String) async throws {
        var payload: [String: AnyJSON] = [
            "id": .string(record.id.uuidString),
            "household_id": .string(householdId),
            "checked_out_to": .string(record.checkedOutTo),
            "checked_out_by": .string(record.checkedOutBy),
            "notes": .string(record.notes),
        ]
        if let itemId = record.item?.id {
            payload["item_id"] = .string(itemId.uuidString)
        }
        if let checkedInAt = record.checkedInAt {
            payload["checked_in_at"] = .string(ISO8601DateFormatter().string(from: checkedInAt))
        }
        if let returnDate = record.expectedReturnDate {
            payload["expected_return_date"] = .string(ISO8601DateFormatter().string(from: returnDate))
        }
        try await client.from("checkout_records").upsert(payload).execute()
    }

    // MARK: - Pull from Supabase

    private func pullZones(householdId: String) async throws {
        guard let context = modelContext else { return }

        let response: [RemoteZone] = try await client.from("zones")
            .select()
            .eq("household_id", value: householdId)
            .execute()
            .value

        for remote in response {
            let remoteId = remote.id
            let descriptor = FetchDescriptor<Zone>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try context.fetch(descriptor).first {
                if remote.updatedAt > existing.updatedAt {
                    existing.name = remote.name
                    existing.locationDescription = remote.locationDescription
                    existing.color = remote.color
                    existing.icon = remote.icon
                    existing.updatedAt = remote.updatedAt
                }
            } else {
                let zone = Zone(name: remote.name, locationDescription: remote.locationDescription,
                                color: remote.color, icon: remote.icon)
                zone.id = remote.id
                zone.householdId = householdId
                zone.updatedAt = remote.updatedAt
                context.insert(zone)
            }
        }
        try context.save()
    }

    private func pullBins(householdId: String) async throws {
        guard let context = modelContext else { return }

        let response: [RemoteBin] = try await client.from("bins")
            .select()
            .eq("household_id", value: householdId)
            .execute()
            .value

        for remote in response {
            let remoteId = remote.id
            let descriptor = FetchDescriptor<Bin>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try context.fetch(descriptor).first {
                if remote.updatedAt > existing.updatedAt {
                    existing.code = remote.code
                    existing.name = remote.name
                    existing.binDescription = remote.binDescription
                    existing.location = remote.location
                    existing.color = remote.color
                    existing.updatedAt = remote.updatedAt
                }
            } else {
                let bin = Bin(code: remote.code, name: remote.name,
                              binDescription: remote.binDescription, location: remote.location)
                bin.id = remote.id
                bin.householdId = householdId
                bin.color = remote.color
                bin.updatedAt = remote.updatedAt

                // Link to zone
                if let zoneId = remote.zoneId {
                    let zoneDescriptor = FetchDescriptor<Zone>(predicate: #Predicate { $0.id == zoneId })
                    bin.zone = try context.fetch(zoneDescriptor).first
                }

                context.insert(bin)
            }
        }
        try context.save()
    }

    private func pullItems(householdId: String) async throws {
        guard let context = modelContext else { return }

        let response: [RemoteItem] = try await client.from("items")
            .select()
            .eq("household_id", value: householdId)
            .execute()
            .value

        for remote in response {
            let remoteId = remote.id
            let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == remoteId })
            if let existing = try context.fetch(descriptor).first {
                if remote.updatedAt > existing.updatedAt {
                    existing.name = remote.name
                    existing.itemDescription = remote.itemDescription
                    existing.color = remote.color
                    existing.notes = remote.notes
                    existing.isCheckedOut = remote.isCheckedOut
                    existing.value = remote.value
                    existing.valueSource = remote.valueSource
                    existing.tags = remote.tags
                    existing.checkoutPermission = remote.checkoutPermission
                    existing.allowedCheckoutUsers = remote.allowedCheckoutUsers
                    existing.maxCheckoutDays = remote.maxCheckoutDays
                    existing.updatedAt = remote.updatedAt
                }
            } else {
                let item = Item(name: remote.name, itemDescription: remote.itemDescription)
                item.id = remote.id
                item.householdId = householdId
                item.color = remote.color
                item.notes = remote.notes
                item.isCheckedOut = remote.isCheckedOut
                item.value = remote.value
                item.valueSource = remote.valueSource
                item.tags = remote.tags
                item.createdBy = remote.createdBy
                item.checkoutPermission = remote.checkoutPermission
                item.allowedCheckoutUsers = remote.allowedCheckoutUsers
                item.maxCheckoutDays = remote.maxCheckoutDays
                item.updatedAt = remote.updatedAt

                if let binId = remote.binId {
                    let binDescriptor = FetchDescriptor<Bin>(predicate: #Predicate { $0.id == binId })
                    item.bin = try context.fetch(binDescriptor).first
                }

                context.insert(item)
            }
        }
        try context.save()
    }

    private func pullCheckoutRecords(householdId: String) async throws {
        guard let context = modelContext else { return }

        let response: [RemoteCheckoutRecord] = try await client.from("checkout_records")
            .select()
            .eq("household_id", value: householdId)
            .execute()
            .value

        for remote in response {
            let remoteId = remote.id
            let descriptor = FetchDescriptor<CheckoutRecord>(predicate: #Predicate { $0.id == remoteId })
            if try context.fetch(descriptor).first == nil {
                let record = CheckoutRecord(
                    checkedOutTo: remote.checkedOutTo,
                    expectedReturnDate: remote.expectedReturnDate,
                    notes: remote.notes
                )
                record.id = remote.id
                record.householdId = householdId
                record.checkedOutBy = remote.checkedOutBy
                record.checkedOutAt = remote.checkedOutAt
                record.checkedInAt = remote.checkedInAt

                let remoteItemId = remote.itemId
                let itemDescriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == remoteItemId })
                record.item = try context.fetch(itemDescriptor).first

                context.insert(record)
            }
        }
        try context.save()
    }

    private func pullCustomAttributes(householdId: String) async throws {
        guard let context = modelContext else { return }

        let response: [RemoteCustomAttribute] = try await client.from("custom_attributes")
            .select()
            .eq("household_id", value: householdId)
            .execute()
            .value

        for remote in response {
            let remoteId = remote.id
            let descriptor = FetchDescriptor<CustomAttribute>(predicate: #Predicate { $0.id == remoteId })
            if try context.fetch(descriptor).first == nil {
                let attr = CustomAttribute(name: remote.name,
                                           type: AttributeType(rawValue: remote.type) ?? .text,
                                           sortOrder: remote.sortOrder)
                attr.id = remote.id
                attr.householdId = householdId
                attr.textValue = remote.textValue
                attr.numberValue = remote.numberValue
                attr.dateValue = remote.dateValue
                attr.boolValue = remote.boolValue

                let remoteItemId = remote.itemId
                let itemDescriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == remoteItemId })
                attr.item = try context.fetch(itemDescriptor).first

                context.insert(attr)
            }
        }
        try context.save()
    }

    // MARK: - Delete

    func deleteRemoteZone(_ id: UUID) async throws {
        try await client.from("zones").delete().eq("id", value: id.uuidString).execute()
    }

    func deleteRemoteBin(_ id: UUID) async throws {
        try await client.from("bins").delete().eq("id", value: id.uuidString).execute()
    }

    func deleteRemoteItem(_ id: UUID) async throws {
        try await client.from("items").delete().eq("id", value: id.uuidString).execute()
    }
}

// MARK: - Remote DTOs (Decodable structs for Supabase responses)

private struct RemoteZone: Decodable {
    let id: UUID
    let name: String
    let locationDescription: String
    let color: String
    let icon: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, color, icon
        case locationDescription = "location_description"
        case updatedAt = "updated_at"
    }
}

private struct RemoteBin: Decodable {
    let id: UUID
    let code: String
    let name: String
    let binDescription: String
    let location: String
    let color: String
    let zoneId: UUID?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, code, name, location, color
        case binDescription = "bin_description"
        case zoneId = "zone_id"
        case updatedAt = "updated_at"
    }
}

private struct RemoteItem: Decodable {
    let id: UUID
    let name: String
    let itemDescription: String
    let color: String
    let notes: String
    let isCheckedOut: Bool
    let value: Double?
    let valueSource: String
    let tags: [String]
    let binId: UUID?
    let createdBy: String
    let checkoutPermission: String
    let allowedCheckoutUsers: [String]
    let maxCheckoutDays: Int?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, color, notes, value, tags
        case itemDescription = "item_description"
        case isCheckedOut = "is_checked_out"
        case valueSource = "value_source"
        case binId = "bin_id"
        case createdBy = "created_by"
        case checkoutPermission = "checkout_permission"
        case allowedCheckoutUsers = "allowed_checkout_users"
        case maxCheckoutDays = "max_checkout_days"
        case updatedAt = "updated_at"
    }
}

private struct RemoteCheckoutRecord: Decodable {
    let id: UUID
    let itemId: UUID
    let checkedOutTo: String
    let checkedOutBy: String
    let checkedOutAt: Date
    let checkedInAt: Date?
    let expectedReturnDate: Date?
    let notes: String

    enum CodingKeys: String, CodingKey {
        case id, notes
        case itemId = "item_id"
        case checkedOutTo = "checked_out_to"
        case checkedOutBy = "checked_out_by"
        case checkedOutAt = "checked_out_at"
        case checkedInAt = "checked_in_at"
        case expectedReturnDate = "expected_return_date"
    }
}

private struct RemoteCustomAttribute: Decodable {
    let id: UUID
    let itemId: UUID
    let name: String
    let type: String
    let textValue: String
    let numberValue: Double?
    let dateValue: Date?
    let boolValue: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case itemId = "item_id"
        case textValue = "text_value"
        case numberValue = "number_value"
        case dateValue = "date_value"
        case boolValue = "bool_value"
        case sortOrder = "sort_order"
    }
}
