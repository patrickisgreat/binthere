import Foundation

enum CurrencyFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter
    }()

    static func format(_ value: Double?) -> String {
        guard let value, value != 0 else { return "—" }
        return formatter.string(from: NSNumber(value: value)) ?? "—"
    }

    static func parse(_ string: String) -> Double? {
        let cleaned = string.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(cleaned)
    }
}
