import SwiftUI
import SwiftData

struct SearchView: View {
    @Query(sort: \Item.name) private var allItems: [Item]
    @Query(sort: \Bin.code) private var allBins: [Bin]

    @State private var searchText = ""
    @State private var selectedTags: Set<String> = []

    private var checkedOutCount: Int {
        allItems.filter(\.isCheckedOut).count
    }

    private var allTags: [String] {
        let tags = Set(allItems.flatMap(\.tags))
        return tags.sorted()
    }

    private var results: SearchResults {
        let query = searchText.trimmingCharacters(in: .whitespaces)

        var items = allItems
        var bins = allBins

        if !selectedTags.isEmpty {
            items = items.filter { item in
                !selectedTags.isDisjoint(with: item.tags)
            }
        }

        if query.isEmpty {
            return SearchResults(items: selectedTags.isEmpty ? [] : items, bins: [])
        }

        items = items.filter { item in
            item.name.localizedCaseInsensitiveContains(query) ||
            item.itemDescription.localizedCaseInsensitiveContains(query) ||
            item.tags.contains { $0.localizedCaseInsensitiveContains(query) } ||
            item.notes.localizedCaseInsensitiveContains(query) ||
            item.color.localizedCaseInsensitiveContains(query)
        }

        bins = bins.filter { bin in
            bin.code.localizedCaseInsensitiveContains(query) ||
            bin.name.localizedCaseInsensitiveContains(query) ||
            bin.location.localizedCaseInsensitiveContains(query) ||
            bin.binDescription.localizedCaseInsensitiveContains(query)
        }

        return SearchResults(items: items, bins: bins)
    }

    var body: some View {
        List {
            if !allTags.isEmpty {
                Section {
                    tagFilterSection
                }
            }

            if searchText.isEmpty && selectedTags.isEmpty {
                if checkedOutCount > 0 {
                    Section {
                        NavigationLink {
                            CheckedOutView()
                                .navigationDestination(for: Item.self) { item in
                                    ItemDetailView(item: item)
                                }
                        } label: {
                            Label {
                                HStack {
                                    Text("Checked Out")
                                    Spacer()
                                    Text("\(checkedOutCount)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Theme.Colors.checkedOut)
                                        .clipShape(Capsule())
                                }
                            } icon: {
                                Image(systemName: "arrow.up.forward.circle")
                                    .foregroundStyle(Theme.Colors.checkedOut)
                            }
                        }
                    }
                }

                ContentUnavailableView(
                    "Search Everything",
                    systemImage: "magnifyingglass",
                    description: Text("Find items, bins, and tags across your entire inventory.")
                )
            } else if results.isEmpty {
                BrandedEmptyState.noSearchResults
            } else {
                if !results.items.isEmpty {
                    Section("Items (\(results.items.count))") {
                        ForEach(results.items) { item in
                            NavigationLink(value: item) {
                                SearchItemRow(item: item, query: searchText)
                            }
                        }
                    }
                }

                if !results.bins.isEmpty {
                    Section("Bins (\(results.bins.count))") {
                        ForEach(results.bins) { bin in
                            NavigationLink(value: bin) {
                                SearchBinRow(bin: bin)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Items, bins, tags…")
        .navigationTitle("Search")
        .navigationDestination(for: Item.self) { item in
            ItemDetailView(item: item)
        }
        .navigationDestination(for: Bin.self) { bin in
            BinDetailView(bin: bin)
        }
    }

    private var tagFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allTags, id: \.self) { tag in
                    Button {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    } label: {
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedTags.contains(tag) ? Color.blue : Color.blue.opacity(0.1))
                            .foregroundStyle(selectedTags.contains(tag) ? .white : .blue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if !selectedTags.isEmpty {
                    Button {
                        selectedTags.removeAll()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

private struct SearchResults {
    let items: [Item]
    let bins: [Bin]

    var isEmpty: Bool { items.isEmpty && bins.isEmpty }
}

private struct SearchItemRow: View {
    let item: Item
    let query: String

    var body: some View {
        HStack(spacing: 12) {
            if let path = item.imagePaths.first,
               let image = ImageStorageService.loadImage(filename: path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.color.isEmpty ? Color.gray.opacity(0.15) : ColorPalette.from(item.color).color.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "cube.box")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.subheadline.weight(.medium))
                    if item.isCheckedOut {
                        Text("OUT")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.Colors.checkedOut.opacity(0.2))
                            .foregroundStyle(Theme.Colors.checkedOut)
                            .clipShape(Capsule())
                    }
                }

                if !item.itemDescription.isEmpty {
                    Text(item.itemDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if let bin = item.bin {
                        Label(bin.displayName, systemImage: "archivebox")
                    }
                    if let value = item.value {
                        Label(CurrencyFormatter.format(value), systemImage: "dollarsign.circle")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)

                if !item.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        if item.tags.count > 3 {
                            Text("+\(item.tags.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SearchBinRow: View {
    let bin: Bin

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(bin.color.isEmpty ? Color.gray.opacity(0.15) : ColorPalette.from(bin.color).color.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "archivebox")
                        .foregroundStyle(bin.color.isEmpty ? .secondary : ColorPalette.from(bin.color).color)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(bin.displayName)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    Label("\(bin.items.count) items", systemImage: "cube.box")
                    if let zone = bin.zone {
                        Label(zone.name, systemImage: "square.grid.2x2")
                    }
                    if !bin.location.isEmpty {
                        Label(bin.location, systemImage: "mappin")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
