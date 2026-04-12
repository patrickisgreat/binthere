import Foundation
import SwiftData

enum AttributeType: String, CaseIterable, Identifiable {
    case text
    case number
    case date
    case boolean
    case currency

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: "Text"
        case .number: "Number"
        case .date: "Date"
        case .boolean: "Yes / No"
        case .currency: "Currency"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "textformat"
        case .number: "number"
        case .date: "calendar"
        case .boolean: "checkmark.circle"
        case .currency: "dollarsign.circle"
        }
    }
}

@Model
final class CustomAttribute {
    var id: UUID = UUID()
    var name: String = ""
    var type: String = AttributeType.text.rawValue
    var textValue: String = ""
    var numberValue: Double?
    var dateValue: Date?
    var boolValue: Bool = false
    var sortOrder: Int = 0

    var item: Item?

    var attributeType: AttributeType {
        get { AttributeType(rawValue: type) ?? .text }
        set { type = newValue.rawValue }
    }

    var displayValue: String {
        switch attributeType {
        case .text:
            return textValue
        case .number:
            guard let num = numberValue else { return "—" }
            return NumberFormatter.localizedString(from: NSNumber(value: num), number: .decimal)
        case .date:
            guard let date = dateValue else { return "—" }
            return date.formatted(date: .abbreviated, time: .omitted)
        case .boolean:
            return boolValue ? "Yes" : "No"
        case .currency:
            guard let num = numberValue else { return "—" }
            return CurrencyFormatter.format(num)
        }
    }

    init(name: String, type: AttributeType = .text, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.type = type.rawValue
        self.sortOrder = sortOrder
    }
}
