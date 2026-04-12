import SwiftUI

struct EditAttributeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: Item
    var existing: CustomAttribute?

    @State private var name: String = ""
    @State private var selectedType: AttributeType = .text
    @State private var textValue: String = ""
    @State private var numberValue: String = ""
    @State private var dateValue: Date = Date()
    @State private var boolValue: Bool = false

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Brand, Purchase Date", text: $name)
                }

                Section("Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(AttributeType.allCases) { type in
                            Label(type.displayName, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Value") {
                    valueField
                }
            }
            .navigationTitle(isEditing ? "Edit Attribute" : "New Attribute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { populateFromExisting() }
        }
    }

    @ViewBuilder
    private var valueField: some View {
        switch selectedType {
        case .text:
            TextField("Value", text: $textValue, axis: .vertical)
                .lineLimit(1...4)
        case .number:
            TextField("0", text: $numberValue)
                .keyboardType(.decimalPad)
        case .date:
            DatePicker("Date", selection: $dateValue, displayedComponents: .date)
        case .boolean:
            Toggle("Value", isOn: $boolValue)
        case .currency:
            HStack {
                Text("$")
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $numberValue)
                    .keyboardType(.decimalPad)
            }
        }
    }

    private func populateFromExisting() {
        guard let existing else { return }
        name = existing.name
        selectedType = existing.attributeType
        textValue = existing.textValue
        if let num = existing.numberValue {
            numberValue = String(format: "%.2f", num)
        }
        if let date = existing.dateValue {
            dateValue = date
        }
        boolValue = existing.boolValue
    }

    private func save() {
        let attribute = existing ?? CustomAttribute(
            name: name,
            type: selectedType,
            sortOrder: item.customAttributes.count
        )

        attribute.name = name.trimmingCharacters(in: .whitespaces)
        attribute.attributeType = selectedType

        // Clear non-matching type fields so the displayValue is correct
        switch selectedType {
        case .text:
            attribute.textValue = textValue
            attribute.numberValue = nil
            attribute.dateValue = nil
            attribute.boolValue = false
        case .number, .currency:
            attribute.numberValue = Double(numberValue)
            attribute.textValue = ""
            attribute.dateValue = nil
            attribute.boolValue = false
        case .date:
            attribute.dateValue = dateValue
            attribute.textValue = ""
            attribute.numberValue = nil
            attribute.boolValue = false
        case .boolean:
            attribute.boolValue = boolValue
            attribute.textValue = ""
            attribute.numberValue = nil
            attribute.dateValue = nil
        }

        if existing == nil {
            attribute.item = item
            modelContext.insert(attribute)
        }

        dismiss()
    }
}
