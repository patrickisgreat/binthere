import SwiftUI
import SwiftData

struct ZoneDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var zone: Zone

    @State private var showingDeleteConfirmation = false
    @State private var showingAddBin = false

    var body: some View {
        List {
            Section {
                headerSection
            }

            Section("Bins (\(zone.bins.count))") {
                if zone.bins.isEmpty {
                    ContentUnavailableView(
                        "No Bins",
                        systemImage: "archivebox",
                        description: Text("Tap + to add a bin to this zone.")
                    )
                } else {
                    ForEach(zone.bins.sorted(by: { $0.code < $1.code })) { bin in
                        NavigationLink(value: bin) {
                            HStack(spacing: 12) {
                                ColorDot(colorName: bin.color, size: 14)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bin.code)
                                        .font(.headline.monospaced())
                                    if !bin.name.isEmpty {
                                        Text(bin.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(bin.items.count) items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                DisclosureGroup("Zone Settings") {
                    LabeledContent("Name") {
                        TextField("Name", text: $zone.name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Description") {
                        TextField("Description", text: $zone.locationDescription, axis: .vertical)
                            .multilineTextAlignment(.trailing)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.subheadline)
                        ColorPickerRow(selectedColor: $zone.color)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.subheadline)
                        IconPickerGrid(selectedIcon: $zone.icon)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                    Label("Delete Zone", systemImage: "trash")
                }
            }
        }
        .navigationTitle(zone.name)
        .navigationDestination(for: Bin.self) { bin in
            BinDetailView(bin: bin)
        }
        .toolbar {
            Button(action: { showingAddBin = true }) {
                Label("Add Bin", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAddBin) {
            AddBinToZoneSheet(zone: zone)
        }
        .alert("Delete Zone?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(zone)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Bins in this zone will keep their data but lose their zone assignment.")
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZoneIcon(iconName: zone.icon, colorName: zone.color, size: 44)
                .frame(width: 50, height: 50)
                .background(ColorPalette.from(zone.color).color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(zone.name)
                    .font(.title3.weight(.semibold))
                HStack(spacing: 12) {
                    Label("\(zone.bins.count) bins", systemImage: "archivebox")
                    Label("\(zone.totalItemCount) items", systemImage: "cube.box")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AddBinToZoneSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allBins: [Bin]

    let zone: Zone

    @State private var label = ""
    @State private var binDescription = ""
    @State private var location = ""
    @State private var selectedColor = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Label (optional)") {
                    TextField("e.g. Garage Shelf, Junk Drawer", text: $label)
                }
                Section("Location") {
                    TextField("Location (optional)", text: $location)
                }
                Section("Color") {
                    ColorPickerRow(selectedColor: $selectedColor)
                }
                Section("Description") {
                    TextField("Description (optional)", text: $binDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Bin in \(zone.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createBin() }
                }
            }
        }
    }

    private func createBin() {
        let existingCodes = Set(allBins.map(\.code))
        let code = CodeGenerator.generateCode(existingCodes: existingCodes)

        let bin = Bin(
            code: code,
            name: label.trimmingCharacters(in: .whitespaces),
            binDescription: binDescription,
            location: location
        )
        bin.zone = zone
        bin.color = selectedColor

        if let labelImage = QRGeneratorService.generateQRLabel(code: code, binID: bin.id.uuidString),
           let labelPath = ImageStorageService.saveImage(labelImage) {
            bin.qrCodeImagePath = labelPath
        }

        modelContext.insert(bin)
        dismiss()
    }
}
