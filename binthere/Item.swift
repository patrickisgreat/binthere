import Foundation
import SwiftData

@Model
final class Item {
    var id: UUID = UUID()
    var name: String = ""
    var itemDescription: String = ""
    var imagePaths: [String] = []
    var tags: [String] = []
    var customFields: [String: String] = [:]
    var color: String = ""
    var createdAt: Date = Date()
    var isCheckedOut: Bool = false

    var bin: Bin?

    @Relationship(deleteRule: .cascade, inverse: \CheckoutRecord.item)
    var checkoutHistory: [CheckoutRecord] = []

    init(name: String, itemDescription: String = "", bin: Bin? = nil) {
        self.id = UUID()
        self.name = name
        self.itemDescription = itemDescription
        self.bin = bin
        self.createdAt = Date()
    }
}
