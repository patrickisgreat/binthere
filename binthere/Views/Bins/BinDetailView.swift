import SwiftUI
import SwiftData

struct BinDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var bin: Bin
    @Query(sort: \Zone.name) private var allZones: [Zone]
    @Query(sort: \Bin.code) private var allBins: [Bin]

    @State private var showingAddItem = false
    @State private var showingAIAnalysis = false
    @State private var showingQRCode = false
    @State private var showingContentCamera = false
    @State private var nfcService = NFCService()
    @State private var showingNFCResult = false
    @State private var itemFilter: ItemFilter = .all
    @State private var selectedItems = Set<UUID>()
    @State private var isEditMode = false
    @State private var showingBulkMove = false
    @State private var showingBulkDeleteConfirmation = false
    @State private var quickAddName = ""
    @State private var showingCheckoutItem: Item?
    @State private var showingMoveItem: Item?
    @FocusState private var quickAddFocused: Bool

    enum ItemFilter: String, CaseIterable {
        case all = "All"
        case available = "Available"
        case checkedOut = "Checked Out"
    }

    private var filteredItems: [Item] {
        switch itemFilter {
        case .all: return bin.items
        case .available: return bin.items.filter { !$0.isCheckedOut }
        case .checkedOut: return bin.items.filter { $0.isCheckedOut }
        }
    }

    var body: some View {
        List {
            Section {
                binInfoSection
            }

            if !bin.contentImagePaths.isEmpty {
                Section("Bin Photos") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(bin.contentImagePaths, id: \.self) { path in
                                if let image = ImageStorageService.loadImage(filename: path) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 150, height: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .listRowInsets(EdgeInsets())
                }
            }

            Section {
                Picker("Filter", selection: $itemFilter) {
                    ForEach(ItemFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.horizontal)
            }

            Section(isEditMode ? "Select Items (\(selectedItems.count) selected)" : "Items (\(filteredItems.count))") {
                if filteredItems.isEmpty && quickAddName.isEmpty {
                    BrandedEmptyState.noItems
                } else {
                    ForEach(filteredItems) { item in
                        if isEditMode {
                            HStack {
                                Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedItems.contains(item.id) ? Theme.Colors.accent : Theme.Colors.secondaryText)
                                ItemRowView(item: item)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.selection()
                                if selectedItems.contains(item.id) {
                                    selectedItems.remove(item.id)
                                } else {
                                    selectedItems.insert(item.id)
                                }
                            }
                        } else {
                            NavigationLink(value: item) {
                                ItemRowView(item: item)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Haptics.medium()
                                    modelContext.delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                if item.isCheckedOut {
                                    Button {
                                        Haptics.success()
                                        if let record = item.checkoutHistory.first(where: { $0.isActive }) {
                                            record.checkedInAt = Date()
                                        }
                                        item.isCheckedOut = false
                                        item.updatedAt = Date()
                                    } label: {
                                        Label("Check In", systemImage: "arrow.down.to.line")
                                    }
                                    .tint(Theme.Colors.success)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if !item.isCheckedOut && item.checkoutPermission != "none" {
                                    Button {
                                        showingCheckoutItem = item
                                    } label: {
                                        Label("Check Out", systemImage: "arrow.up.right")
                                    }
                                    .tint(Theme.Colors.checkedOut)
                                }
                            }
                            .contextMenu {
                                if item.isCheckedOut {
                                    Button {
                                        Haptics.success()
                                        if let record = item.checkoutHistory.first(where: { $0.isActive }) {
                                            record.checkedInAt = Date()
                                        }
                                        item.isCheckedOut = false
                                        item.updatedAt = Date()
                                    } label: {
                                        Label("Check In", systemImage: "arrow.down.to.line")
                                    }
                                } else if item.checkoutPermission != "none" {
                                    Button {
                                        showingCheckoutItem = item
                                    } label: {
                                        Label("Check Out", systemImage: "arrow.up.right")
                                    }
                                }
                                Button {
                                    showingMoveItem = item
                                } label: {
                                    Label("Move to Bin", systemImage: "arrow.right.arrow.left")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    Haptics.medium()
                                    modelContext.delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // Quick add row
                if !isEditMode {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.Colors.accent)
                        TextField("Add item...", text: $quickAddName)
                            .font(Theme.Typography.body)
                            .focused($quickAddFocused)
                            .onSubmit { quickAddItem() }
                            .submitLabel(.done)
                    }
                    .padding(.vertical, Theme.Spacing.xxs)
                }
            }
        }
        .navigationTitle(bin.code)
        .navigationDestination(for: Item.self) { item in
            ItemDetailView(item: item)
        }
        .toolbar {
            if isEditMode {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isEditMode = false
                        selectedItems.removeAll()
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: { showingBulkMove = true }) {
                        Label("Move", systemImage: "arrow.right.arrow.left")
                    }
                    .disabled(selectedItems.isEmpty)

                    Spacer()

                    Button(action: selectAll) {
                        Label(
                            selectedItems.count == filteredItems.count ? "Deselect All" : "Select All",
                            systemImage: selectedItems.count == filteredItems.count ? "circle" : "checkmark.circle"
                        )
                    }

                    Spacer()

                    Button(role: .destructive, action: { showingBulkDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selectedItems.isEmpty)
                }
            } else {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { showingAIAnalysis = true }) {
                        Label("AI Scan", systemImage: "sparkles")
                    }
                    Button(action: { showingAddItem = true }) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button(action: { isEditMode = true }) {
                            Label("Select Items", systemImage: "checkmark.circle")
                        }
                        Button(action: { showingQRCode = true }) {
                            Label("Show QR Label", systemImage: "qrcode")
                        }
                        Button(action: { nfcService.writeTag(binID: bin.id.uuidString) }) {
                            Label("Write NFC Tag", systemImage: "wave.3.right")
                        }
                        Button(action: { showingContentCamera = true }) {
                            Label("Add Bin Photo", systemImage: "camera")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(bin: bin)
                .cardPresentation()
        }
        .sheet(isPresented: $showingAIAnalysis) {
            AIAnalysisView(bin: bin)
                .cardPresentation()
        }
        .sheet(isPresented: $showingQRCode) {
            QRLabelSheet(bin: bin)
                .cardPresentation()
        }
        .sheet(isPresented: $showingContentCamera) {
            ImagePickerView(selectedImage: .init(
                get: { nil },
                set: { newImage in
                    if let image = newImage, let path = ImageStorageService.saveImage(image) {
                        bin.contentImagePaths.append(path)
                    }
                }
            ), sourceType: .camera)
        }
        .sheet(isPresented: $showingBulkMove) {
            BulkMoveSheet(items: selectedItemObjects, allBins: allBins) {
                isEditMode = false
                selectedItems.removeAll()
            }
        }
        .alert("Delete \(selectedItems.count) Items?", isPresented: $showingBulkDeleteConfirmation) {
            Button("Delete", role: .destructive) { bulkDelete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete the selected items and their checkout history.")
        }
        .sheet(item: $showingCheckoutItem) { item in
            CheckoutSheet(item: item, defaultName: "")
                .cardPresentation()
        }
        .sheet(item: $showingMoveItem) { item in
            MoveBinSheet(item: item, bins: allBins)
                .cardPresentation()
        }
    }

    private var selectedItemObjects: [Item] {
        bin.items.filter { selectedItems.contains($0.id) }
    }

    private func selectAll() {
        if selectedItems.count == filteredItems.count {
            selectedItems.removeAll()
        } else {
            selectedItems = Set(filteredItems.map(\.id))
        }
    }

    private func bulkDelete() {
        Haptics.success()
        for item in selectedItemObjects {
            modelContext.delete(item)
        }
        selectedItems.removeAll()
        isEditMode = false
    }

    private func quickAddItem() {
        let name = quickAddName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let item = Item(name: name, bin: bin)
        modelContext.insert(item)
        Haptics.light()
        withAnimation(Theme.Animation.spring) {
            quickAddName = ""
        }
    }

    private var binInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ColorDot(colorName: bin.color, size: 14)
                Text(bin.code)
                    .font(.headline.monospaced())
                if !bin.name.isEmpty {
                    Text("· \(bin.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if !bin.binDescription.isEmpty {
                Text(bin.binDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Picker("Zone", selection: $bin.zone) {
                Text("No Zone").tag(nil as Zone?)
                ForEach(allZones) { zone in
                    Label {
                        Text(zone.name)
                    } icon: {
                        ZoneIcon(iconName: zone.icon, colorName: zone.color)
                    }
                    .tag(zone as Zone?)
                }
            }
            .font(.subheadline)

            if !bin.location.isEmpty {
                Label(bin.location, systemImage: "location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if bin.totalValue > 0 {
                Label {
                    Text("\(CurrencyFormatter.format(bin.totalValue)) · \(bin.itemsWithValueCount) item\(bin.itemsWithValueCount == 1 ? "" : "s")")
                } icon: {
                    Image(systemName: "dollarsign.circle")
                }
                .font(.caption)
                .foregroundStyle(.green)
            }
        }
    }
}

struct ItemRowView: View {
    let item: Item

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let firstImagePath = item.imagePaths.first,
               let image = ImageStorageService.loadImage(filename: firstImagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            } else {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Theme.Colors.secondaryBackground)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "cube.box")
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
            }

            ColorDot(colorName: item.color)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(item.name)
                    .font(Theme.Typography.headline)
                if !item.tags.isEmpty {
                    Text(item.tags.joined(separator: ", "))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            if item.isCheckedOut {
                Text("OUT")
                    .font(Theme.Typography.caption2.weight(.bold))
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(Theme.Colors.checkedOut.opacity(0.15))
                    .foregroundStyle(Theme.Colors.checkedOut)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

private struct QRLabelSheet: View {
    let bin: Bin
    @Environment(\.dismiss) private var dismiss

    private var labelImage: UIImage? {
        if let qrPath = bin.qrCodeImagePath,
           let stored = ImageStorageService.loadImage(filename: qrPath) {
            return stored
        }
        return QRGeneratorService.generateQRLabel(code: bin.code, binID: bin.id.uuidString)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(bin.code)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))

                if !bin.name.isEmpty {
                    Text(bin.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let labelImage {
                    Image(uiImage: labelImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 2)

                    HStack(spacing: 16) {
                        ShareLink(
                            item: Image(uiImage: labelImage),
                            preview: SharePreview("Bin \(bin.code)", image: Image(uiImage: labelImage))
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)

                        Button(action: { printLabel(labelImage) }) {
                            Label("Print", systemImage: "printer")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ContentUnavailableView(
                        "Label Generation Failed",
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func printLabel(_ image: UIImage) {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Bin \(bin.code)"
        printInfo.outputType = .photo

        let printer = UIPrintInteractionController.shared
        printer.printInfo = printInfo
        printer.printingItem = image
        printer.present(animated: true)
    }
}

private struct BulkMoveSheet: View {
    @Environment(\.dismiss) private var dismiss
    let items: [Item]
    let allBins: [Bin]
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            List(allBins) { bin in
                Button {
                    for item in items {
                        item.bin = bin
                        item.updatedAt = Date()
                    }
                    onComplete()
                    dismiss()
                } label: {
                    HStack {
                        ColorDot(colorName: bin.color, size: 14)
                        Text(bin.displayName)
                        Spacer()
                        Text("\(bin.items.count) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Move \(items.count) Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
