import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: Item

    @Query(sort: \Bin.name) private var allBins: [Bin]
    @State private var showingCheckout = false
    @State private var showingMoveBin = false
    @State private var showingDeleteConfirmation = false
    @State private var showingImagePicker = false
    @State private var showingSetValue = false
    @State private var editingAttribute: CustomAttribute?
    @State private var showingNewAttribute = false

    var body: some View {
        List {
            if !item.imagePaths.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(item.imagePaths, id: \.self) { path in
                                if let image = ImageStorageService.loadImage(filename: path) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 200, height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .listRowInsets(EdgeInsets())
                }
            }

            Section("Details") {
                LabeledContent("Name") {
                    TextField("Name", text: $item.name)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Description") {
                    TextField("Description", text: $item.itemDescription, axis: .vertical)
                        .multilineTextAlignment(.trailing)
                }
                if let bin = item.bin {
                    LabeledContent("Bin", value: bin.displayName)
                }
            }

            Section("Value") {
                Button(action: { showingSetValue = true }) {
                    HStack {
                        Image(systemName: "dollarsign.circle")
                        Text(CurrencyFormatter.format(item.value))
                            .foregroundStyle(item.value == nil ? .secondary : .primary)
                        Spacer()
                        if !item.valueSource.isEmpty {
                            Text(item.valueSource == "ai" ? "AI" : "Manual")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Notes") {
                TextField("Add notes about this item...", text: $item.notes, axis: .vertical)
                    .lineLimit(3...10)
            }

            Section {
                ForEach(item.customAttributes.sorted(by: { $0.sortOrder < $1.sortOrder })) { attribute in
                    Button(action: { editingAttribute = attribute }) {
                        HStack {
                            Image(systemName: attribute.attributeType.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(attribute.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(attribute.displayValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteAttributes)

                Button(action: { showingNewAttribute = true }) {
                    Label("Add Attribute", systemImage: "plus.circle")
                }
            } header: {
                Text("Custom Attributes")
            }

            Section("Color") {
                ColorPickerRow(selectedColor: $item.color)
            }

            Section("Tags") {
                if item.tags.isEmpty {
                    Text("No tags")
                        .foregroundStyle(.secondary)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if !item.customFields.isEmpty {
                Section("Custom Fields") {
                    ForEach(Array(item.customFields.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                    }
                }
            }

            Section("Status") {
                statusSection
            }

            Section("Actions") {
                Button(action: { showingMoveBin = true }) {
                    Label("Move to Another Bin", systemImage: "arrow.right.arrow.left")
                }
                Button(action: { showingImagePicker = true }) {
                    Label("Add Photo", systemImage: "camera")
                }
                Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                    Label("Remove Item", systemImage: "trash")
                }
            }

            if !item.checkoutHistory.isEmpty {
                Section("Checkout History") {
                    ForEach(item.checkoutHistory.sorted(by: { $0.checkedOutAt > $1.checkedOutAt })) { record in
                        CheckoutRecordRow(record: record)
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .sheet(isPresented: $showingCheckout) {
            CheckoutSheet(item: item)
        }
        .sheet(isPresented: $showingMoveBin) {
            MoveBinSheet(item: item, bins: allBins)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(selectedImage: .init(
                get: { nil },
                set: { newImage in
                    if let image = newImage, let filename = ImageStorageService.saveImage(image) {
                        item.imagePaths.append(filename)
                    }
                }
            ), sourceType: .camera)
        }
        .alert("Remove Item?", isPresented: $showingDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                modelContext.delete(item)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove this item and its checkout history.")
        }
        .sheet(isPresented: $showingSetValue) {
            SetValueSheet(item: item)
        }
        .sheet(isPresented: $showingNewAttribute) {
            EditAttributeSheet(item: item, existing: nil)
        }
        .sheet(item: $editingAttribute) { attribute in
            EditAttributeSheet(item: item, existing: attribute)
        }
    }

    private func deleteAttributes(at offsets: IndexSet) {
        let sorted = item.customAttributes.sorted(by: { $0.sortOrder < $1.sortOrder })
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if item.isCheckedOut,
           let activeRecord = item.checkoutHistory.first(where: { $0.isActive }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Checked out to \(activeRecord.checkedOutTo)", systemImage: "person")
                    Text("Since \(activeRecord.checkedOutAt, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let returnDate = activeRecord.expectedReturnDate {
                        Text("Expected return: \(returnDate, style: .date)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            Button("Check In") {
                activeRecord.checkedInAt = Date()
                item.isCheckedOut = false
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        } else {
            HStack {
                Label("Available", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                Spacer()
            }
            Button("Check Out") {
                showingCheckout = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct CheckoutRecordRow: View {
    let record: CheckoutRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.checkedOutTo)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if record.isActive {
                    Text("ACTIVE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }
            Text("Out: \(record.checkedOutAt, style: .date)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let checkedIn = record.checkedInAt {
                Text("In: \(checkedIn, style: .date)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !record.notes.isEmpty {
                Text(record.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct CheckoutSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let item: Item

    @State private var checkedOutTo = ""
    @State private var notes = ""
    @State private var hasReturnDate = false
    @State private var expectedReturnDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Who's taking it?") {
                    TextField("Name", text: $checkedOutTo)
                }
                Section("Return Date") {
                    Toggle("Set return date", isOn: $hasReturnDate)
                    if hasReturnDate {
                        DatePicker("Expected return", selection: $expectedReturnDate, displayedComponents: .date)
                    }
                }
                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Check Out")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Check Out") { performCheckout() }
                        .disabled(checkedOutTo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func performCheckout() {
        let record = CheckoutRecord(
            item: item,
            checkedOutTo: checkedOutTo.trimmingCharacters(in: .whitespaces),
            expectedReturnDate: hasReturnDate ? expectedReturnDate : nil,
            notes: notes
        )
        modelContext.insert(record)
        item.isCheckedOut = true
        dismiss()
    }
}

private struct MoveBinSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: Item
    let bins: [Bin]

    var body: some View {
        NavigationStack {
            List(bins) { bin in
                Button {
                    item.bin = bin
                    dismiss()
                } label: {
                    HStack {
                        Text(bin.name)
                        Spacer()
                        if bin.id == item.bin?.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Move to Bin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
