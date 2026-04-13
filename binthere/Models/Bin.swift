import Foundation
import SwiftData

@Model
final class Bin {
    var id: UUID = UUID()
    var householdId: String = ""
    var code: String = ""
    var name: String = ""
    var binDescription: String = ""
    var location: String = ""
    var color: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var qrCodeImagePath: String?
    var contentImagePaths: [String] = []

    var zone: Zone?

    @Relationship(deleteRule: .cascade, inverse: \Item.bin)
    var items: [Item] = []

    /// Display name: code with optional label
    var displayName: String {
        if name.isEmpty {
            return code
        }
        return "\(code) — \(name)"
    }

    var totalValue: Double {
        items.compactMap(\.value).reduce(0, +)
    }

    var itemsWithValueCount: Int {
        items.filter { $0.value != nil }.count
    }

    init(code: String, name: String = "", binDescription: String = "", location: String = "") {
        self.id = UUID()
        self.code = code
        self.name = name
        self.binDescription = binDescription
        self.location = location
        self.createdAt = Date()
    }
}
