import Foundation
import SwiftData

@Model
final class Bin {
    var id: UUID = UUID()
    var name: String = ""
    var binDescription: String = ""
    var location: String = ""
    var createdAt: Date = Date()
    var qrCodeImagePath: String?
    var contentImagePaths: [String] = []

    var zone: Zone?

    @Relationship(deleteRule: .cascade, inverse: \Item.bin)
    var items: [Item] = []

    init(name: String, binDescription: String = "", location: String = "") {
        self.id = UUID()
        self.name = name
        self.binDescription = binDescription
        self.location = location
        self.createdAt = Date()
    }
}
