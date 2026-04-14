import SwiftUI
import SwiftData

struct BinListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bin.code) private var bins: [Bin]
    @Query(sort: \Zone.name) private var allZones: [Zone]
    @State private var searchText = ""
    @State private var showingAddBin = false
    @State private var groupByZone = false
    @State private var isEditMode = false
    @State private var selectedBins = Set<UUID>()
    @State private var showingBulkZoneMove = false
    @State private var showingBulkDeleteConfirmation = false

    private var filteredBins: [Bin] {
        if searchText.isEmpty { return bins }
        return bins.filter { bin in
            bin.code.localizedCaseInsensitiveContains(searchText) ||
            bin.name.localizedCaseInsensitiveContains(searchText) ||
            bin.location.localizedCaseInsensitiveContains(searchText) ||
            (bin.zone?.name.localizedCaseInsensitiveContains(searchText) ?? false) ||
            bin.items.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var groupedBins: [(zone: Zone?, bins: [Bin])] {
        let dict = Dictionary(grouping: filteredBins) { $0.zone }
        var result: [(zone: Zone?, bins: [Bin])] = []

        // Named zones first, sorted alphabetically
        let namedZones = dict.keys
            .compactMap { $0 }
            .sorted { $0.name < $1.name }

        for zone in namedZones {
            if let zoneBins = dict[zone] {
                result.append((zone: zone, bins: zoneBins.sorted { $0.code < $1.code }))
            }
        }

        // Unzoned bins last
        if let unzoned = dict[nil] {
            result.append((zone: nil, bins: unzoned.sorted { $0.code < $1.code }))
        }

        return result
    }

    var body: some View {
        List {
            if filteredBins.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Bins Yet" : "No Results",
                    systemImage: searchText.isEmpty ? "archivebox" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "Tap + to create your first bin." : "No bins match your search.")
                )
            } else if groupByZone {
                ForEach(groupedBins, id: \.zone?.id) { group in
                    Section {
                        ForEach(group.bins) { bin in
                            NavigationLink(value: bin) {
                                BinRowView(bin: bin)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(group.bins[index])
                            }
                        }
                    } header: {
                        if let zone = group.zone {
                            Label {
                                Text(zone.name)
                            } icon: {
                                ZoneIcon(iconName: zone.icon, colorName: zone.color, size: 16)
                            }
                        } else {
                            Text("No Zone")
                        }
                    }
                }
            } else {
                ForEach(filteredBins) { bin in
                    if isEditMode {
                        HStack {
                            Image(systemName: selectedBins.contains(bin.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedBins.contains(bin.id) ? .blue : .secondary)
                            BinRowView(bin: bin)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedBins.contains(bin.id) {
                                selectedBins.remove(bin.id)
                            } else {
                                selectedBins.insert(bin.id)
                            }
                        }
                    } else {
                        NavigationLink(value: bin) {
                            BinRowView(bin: bin)
                        }
                    }
                }
                .onDelete(perform: isEditMode ? nil : deleteBins)
            }
        }
        .navigationTitle(isEditMode ? "\(selectedBins.count) Selected" : "Bins")
        .navigationDestination(for: Bin.self) { bin in
            BinDetailView(bin: bin)
        }
        .searchable(text: $searchText, prompt: "Search by code, label, or items")
        .toolbar {
            if isEditMode {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isEditMode = false
                        selectedBins.removeAll()
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: { showingBulkZoneMove = true }) {
                        Label("Move to Zone", systemImage: "mappin.and.ellipse")
                    }
                    .disabled(selectedBins.isEmpty)

                    Spacer()

                    Button(action: selectAllBins) {
                        Label(
                            selectedBins.count == filteredBins.count ? "Deselect All" : "Select All",
                            systemImage: selectedBins.count == filteredBins.count ? "circle" : "checkmark.circle"
                        )
                    }

                    Spacer()

                    Button(role: .destructive, action: { showingBulkDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selectedBins.isEmpty)
                }
            } else {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button(action: { groupByZone.toggle() }) {
                            Label(
                                groupByZone ? "Flat List" : "Group by Zone",
                                systemImage: groupByZone ? "list.bullet" : "rectangle.3.group"
                            )
                        }
                        Button(action: { isEditMode = true }) {
                            Label("Select Bins", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Label("Options", systemImage: "ellipsis.circle")
                    }

                    Button(action: { showingAddBin = true }) {
                        Label("Add Bin", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddBin) {
            AddBinView()
        }
        .sheet(isPresented: $showingBulkZoneMove) {
            BulkZoneMoveSheet(bins: selectedBinObjects, allZones: allZones) {
                isEditMode = false
                selectedBins.removeAll()
            }
        }
        .alert("Delete \(selectedBins.count) Bins?", isPresented: $showingBulkDeleteConfirmation) {
            Button("Delete", role: .destructive) { bulkDeleteBins() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete the selected bins and all their items.")
        }
    }

    private var selectedBinObjects: [Bin] {
        bins.filter { selectedBins.contains($0.id) }
    }

    private func selectAllBins() {
        if selectedBins.count == filteredBins.count {
            selectedBins.removeAll()
        } else {
            selectedBins = Set(filteredBins.map(\.id))
        }
    }

    private func deleteBins(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredBins[index])
        }
    }

    private func bulkDeleteBins() {
        for bin in selectedBinObjects {
            modelContext.delete(bin)
        }
        selectedBins.removeAll()
        isEditMode = false
    }
}

private struct BulkZoneMoveSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bins: [Bin]
    let allZones: [Zone]
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    for bin in bins { bin.zone = nil; bin.updatedAt = Date() }
                    onComplete()
                    dismiss()
                } label: {
                    Label("No Zone", systemImage: "minus.circle")
                }

                ForEach(allZones) { zone in
                    Button {
                        for bin in bins { bin.zone = zone; bin.updatedAt = Date() }
                        onComplete()
                        dismiss()
                    } label: {
                        HStack {
                            ZoneIcon(iconName: zone.icon, colorName: zone.color)
                            Text(zone.name)
                            Spacer()
                            Text("\(zone.bins.count) bins")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Move \(bins.count) Bins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct BinRowView: View {
    let bin: Bin

    var body: some View {
        HStack(spacing: 12) {
            ColorDot(colorName: bin.color, size: 16)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(bin.code)
                        .font(.headline.monospaced())
                    if !bin.name.isEmpty {
                        Text(bin.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    if let zone = bin.zone {
                        Label {
                            Text(zone.name)
                        } icon: {
                            ZoneIcon(iconName: zone.icon, colorName: zone.color, size: 12)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if !bin.location.isEmpty {
                        Label(bin.location, systemImage: "location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Label("\(bin.items.count) items", systemImage: "cube.box")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
