import SwiftUI
import SwiftData

struct BinListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bin.code) private var bins: [Bin]
    @State private var searchText = ""
    @State private var showingAddBin = false

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

    var body: some View {
        List {
            if filteredBins.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Bins Yet" : "No Results",
                    systemImage: searchText.isEmpty ? "archivebox" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "Tap + to create your first bin." : "No bins match your search.")
                )
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
            Button(action: { showingAddBin = true }) {
                Label("Add Bin", systemImage: "plus")
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
                        Label(zone.name, systemImage: "mappin")
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
