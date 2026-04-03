import SwiftUI
import SwiftData

struct ZoneDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var zone: Zone

    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                headerSection
            }

            Section("Details") {
                LabeledContent("Name") {
                    TextField("Name", text: $zone.name)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Description") {
                    TextField("Description", text: $zone.locationDescription, axis: .vertical)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Color") {
                ColorPickerRow(selectedColor: $zone.color)
            }

            Section("Icon") {
                IconPickerGrid(selectedIcon: $zone.icon)
            }

            Section("Bins (\(zone.bins.count))") {
                if zone.bins.isEmpty {
                    ContentUnavailableView(
                        "No Bins",
                        systemImage: "archivebox",
                        description: Text("No bins are assigned to this zone yet.")
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
                Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                    Label("Delete Zone", systemImage: "trash")
                }
            }
        }
        .navigationTitle(zone.name)
        .navigationDestination(for: Bin.self) { bin in
            BinDetailView(bin: bin)
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
