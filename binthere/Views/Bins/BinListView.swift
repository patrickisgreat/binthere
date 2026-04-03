import SwiftUI
import SwiftData

struct BinListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bin.code) private var bins: [Bin]
    @State private var searchText = ""
    @State private var showingAddBin = false
    @State private var groupByZone = false

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
                    NavigationLink(value: bin) {
                        BinRowView(bin: bin)
                    }
                }
                .onDelete(perform: deleteBins)
            }
        }
        .navigationTitle("Bins")
        .navigationDestination(for: Bin.self) { bin in
            BinDetailView(bin: bin)
        }
        .searchable(text: $searchText, prompt: "Search by code, label, or items")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { groupByZone.toggle() }) {
                    Label(
                        groupByZone ? "Flat List" : "Group by Zone",
                        systemImage: groupByZone ? "list.bullet" : "rectangle.3.group"
                    )
                }
                Button(action: { showingAddBin = true }) {
                    Label("Add Bin", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddBin) {
            AddBinView()
        }
    }

    private func deleteBins(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredBins[index])
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
