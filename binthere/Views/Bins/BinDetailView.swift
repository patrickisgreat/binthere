import SwiftUI
import SwiftData

struct BinDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var bin: Bin

    @State private var showingAddItem = false
    @State private var showingAIAnalysis = false
    @State private var showingQRCode = false
    @State private var showingContentCamera = false
    @State private var itemFilter: ItemFilter = .all

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

            Section("Items (\(filteredItems.count))") {
                if filteredItems.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "cube.box",
                        description: Text("Tap + or use AI Scan to add items.")
                    )
                } else {
                    ForEach(filteredItems) { item in
                        NavigationLink(value: item) {
                            ItemRowView(item: item)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(bin.name)
        .navigationDestination(for: Item.self) { item in
            ItemDetailView(item: item)
        }
        .toolbar {
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
                    Button(action: { showingQRCode = true }) {
                        Label("Show QR Code", systemImage: "qrcode")
                    }
                    Button(action: { showingContentCamera = true }) {
                        Label("Add Bin Photo", systemImage: "camera")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(bin: bin)
        }
        .sheet(isPresented: $showingAIAnalysis) {
            AIAnalysisView(bin: bin)
        }
        .sheet(isPresented: $showingQRCode) {
            QRCodeSheet(bin: bin)
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
    }

    private var binInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !bin.binDescription.isEmpty {
                Text(bin.binDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                if let zone = bin.zone {
                    Label(zone.name, systemImage: "mappin")
                        .font(.caption)
                }
                if !bin.location.isEmpty {
                    Label(bin.location, systemImage: "location")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}

private struct ItemRowView: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            if let firstImagePath = item.imagePaths.first,
               let image = ImageStorageService.loadImage(filename: firstImagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "cube.box")
                            .foregroundStyle(.tertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                if !item.tags.isEmpty {
                    Text(item.tags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if item.isCheckedOut {
                Text("OUT")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

private struct QRCodeSheet: View {
    let bin: Bin
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(bin.name)
                    .font(.title2.weight(.semibold))

                if let qrPath = bin.qrCodeImagePath,
                   let qrImage = ImageStorageService.loadImage(filename: qrPath) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                } else if let qrImage = QRGeneratorService.generateQRCode(from: bin.id.uuidString) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                } else {
                    ContentUnavailableView(
                        "QR Generation Failed",
                        systemImage: "exclamationmark.triangle"
                    )
                }

                Text(bin.id.uuidString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                ShareLink(item: bin.id.uuidString, subject: Text("Bin: \(bin.name)")) {
                    Label("Share QR Data", systemImage: "square.and.arrow.up")
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
}
