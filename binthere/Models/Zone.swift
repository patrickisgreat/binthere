import Foundation
import SwiftData

@Model
final class Zone {
    var id: UUID = UUID()
    var name: String = ""
    var locationDescription: String = ""

    @Relationship(deleteRule: .nullify, inverse: \Bin.zone)
    var bins: [Bin] = []

    init(name: String, locationDescription: String = "") {
        self.id = UUID()
        self.name = name
        self.locationDescription = locationDescription
    }
}
