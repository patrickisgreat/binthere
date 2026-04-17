import Foundation
import SwiftData

@Model
final class Zone {
    var id: UUID = UUID()
    var householdId: String = ""
    var name: String = ""
    var locationDescription: String = ""
    var color: String = ""
    var icon: String = ""
    var locations: [String] = []
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Bin.zone)
    var bins: [Bin] = []

    var totalItemCount: Int {
        bins.reduce(0) { $0 + $1.items.count }
    }

    var totalValue: Double {
        bins.reduce(0) { $0 + $1.totalValue }
    }

    init(name: String, locationDescription: String = "", color: String = "", icon: String = "") {
        self.id = UUID()
        self.name = name
        self.locationDescription = locationDescription
        self.color = color
        self.icon = icon
    }
}
