import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Environment(HouseholdService.self) private var householdService
    @Bindable var item: Item

    @Query(sort: \Bin.name) private var allBins: [Bin]
    @State private var showingCheckout = false
    @State private var showingMoveBin = false
    @State private var showingDeleteConfirmation = false
    @State private var showingImagePicker = false
    @State private var showingSetValue = false
    @State private var showingRequestReturn = false
    @State private var editingAttribute: CustomAttribute?
    @State private var showingNewAttribute = false
    @State private var transferTarget = ""

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

            Section("Ownership") {
                LabeledContent("Owner") {
                    Text(ownerDisplayName)
                }

                if isOwnedByCurrentUser {
                    Picker("Transfer to", selection: $transferTarget) {
                        Text("Keep (me)").tag("")
                        ForEach(otherMembers, id: \.id) { member in
                            Text(member.displayName).tag(member.userId.uuidString.lowercased())
                        }
                    }
                    .onChange(of: transferTarget) { _, newValue in
                        if !newValue.isEmpty {
                            item.createdBy = newValue
                            item.updatedAt = Date()
                            transferTarget = ""
                        }
                    }
                }
            }

            Section("Checkout Permissions") {
                Picker("Who can check out", selection: $item.checkoutPermission) {
                    Text("Anyone").tag("anyone")
                    Text("Nobody").tag("none")
                }

                HStack {
                    Text("Max checkout days")
                    Spacer()
                    TextField("None", value: $item.maxCheckoutDays, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
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
            CheckoutSheet(item: item, defaultName: currentUserDisplayName)
                .cardPresentation()
        }
        .sheet(isPresented: $showingRequestReturn) {
            if let activeRecord = item.checkoutHistory.first(where: { $0.isActive }) {
                RequestItemSheet(item: item, activeRecord: activeRecord)
                    .cardPresentation()
            }
        }
        .sheet(isPresented: $showingMoveBin) {
            MoveBinSheet(item: item, bins: allBins)
                .cardPresentation()
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
                .cardPresentation()
        }
        .sheet(isPresented: $showingNewAttribute) {
            EditAttributeSheet(item: item, existing: nil)
                .cardPresentation()
        }
        .sheet(item: $editingAttribute) { attribute in
            EditAttributeSheet(item: item, existing: attribute)
                .cardPresentation()
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
                item.updatedAt = Date()
                NotificationService.cancelDueBackReminders(for: item.id)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button("Request Return") {
                showingRequestReturn = true
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        } else if item.checkoutPermission == "none" {
            HStack {
                Label("Not available for checkout", systemImage: "lock")
                    .foregroundStyle(.secondary)
                Spacer()
            }
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

    private var ownerDisplayName: String {
        if item.createdBy.isEmpty { return "Unknown" }
        return householdService.members
            .first { $0.userId.uuidString.lowercased() == item.createdBy }?
            .displayName ?? "Unknown"
    }

    private var isOwnedByCurrentUser: Bool {
        item.createdBy == authService.currentUserId
    }

    private var otherMembers: [HouseholdMember] {
        householdService.members.filter {
            $0.userId.uuidString.lowercased() != authService.currentUserId
        }
    }

    private var currentUserDisplayName: String {
        householdService.members
            .first { $0.userId.uuidString.lowercased() == authService.currentUserId }?
            .displayName ?? authService.currentEmail ?? ""
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

struct CheckoutSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HouseholdService.self) private var householdService
    @Environment(AuthService.self) private var authService
    let item: Item
    var defaultName: String = ""

    @State private var checkedOutTo = ""
    @State private var customName = ""
    @State private var notes = ""
    @State private var hasReturnDate = false
    @State private var expectedReturnDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    private var resolvedName: String {
        let name = checkedOutTo == "__custom__" ? customName : checkedOutTo
        return name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Who's taking it?") {
                    if householdService.members.count > 1 {
                        Picker("Person", selection: $checkedOutTo) {
                            ForEach(householdService.members, id: \.id) { member in
                                Text(member.displayName).tag(member.displayName)
                            }
                            Divider()
                            Text("Someone else…").tag("__custom__")
                        }
                        if checkedOutTo == "__custom__" {
                            TextField("Name", text: $customName)
                        }
                    } else {
                        TextField("Name", text: $checkedOutTo)
                    }
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
                        .disabled(resolvedName.isEmpty)
                }
            }
            .onAppear {
                if !defaultName.isEmpty {
                    checkedOutTo = defaultName
                } else if let first = householdService.members.first?.displayName {
                    checkedOutTo = first
                }
            }
        }
    }

    private func performCheckout() {
        let name = resolvedName
        let record = CheckoutRecord(
            item: item,
            checkedOutTo: name,
            expectedReturnDate: hasReturnDate ? expectedReturnDate : nil,
            notes: notes
        )
        record.checkedOutBy = authService.currentUserId ?? ""
        record.householdId = item.householdId
        modelContext.insert(record)
        item.isCheckedOut = true
        item.updatedAt = Date()

        if hasReturnDate {
            NotificationService.scheduleDueBackReminder(
                itemId: item.id, itemName: item.name,
                checkedOutTo: name, dueDate: expectedReturnDate
            )
            NotificationService.scheduleDueBackWarning(
                itemId: item.id, itemName: item.name,
                checkedOutTo: name, dueDate: expectedReturnDate
            )
        }

        dismiss()
    }
}

struct MoveBinSheet: View {
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
