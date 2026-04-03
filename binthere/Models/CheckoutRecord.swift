import Foundation
import SwiftData

@Model
final class CheckoutRecord {
    var id: UUID = UUID()
    var checkedOutAt: Date = Date()
    var checkedInAt: Date?
    var checkedOutTo: String = ""
    var notes: String = ""
    var expectedReturnDate: Date?

    var item: Item?

    var isActive: Bool {
        checkedInAt == nil
    }

    init(item: Item, checkedOutTo: String, expectedReturnDate: Date? = nil, notes: String = "") {
        self.id = UUID()
        self.item = item
        self.checkedOutTo = checkedOutTo
        self.checkedOutAt = Date()
        self.expectedReturnDate = expectedReturnDate
        self.notes = notes
    }
}
