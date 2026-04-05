import SwiftUI
import SwiftData

struct ZoneManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Zone.name) private var zones: [Zone]
    @State private var showingAddZone = false
    @State private var showingHomeKitImport = false

    var body: some View {
        List {
            if zones.isEmpty {
                ContentUnavailableView(
                    "No Zones",
                    systemImage: "mappin.slash",
                    description: Text("Zones help organize bins by area (e.g. Garage, Office, Attic).")
                )
            } else {
                ForEach(zones) { zone in
                    NavigationLink(value: zone) {
                        ZoneRowView(zone: zone)
                    }
                }
                .onDelete(perform: deleteZones)
            }
        }
        .navigationTitle("Zones")
        .navigationDestination(for: Zone.self) { zone in
            ZoneDetailView(zone: zone)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(action: { showingAddZone = true }) {
                        Label("New Zone", systemImage: "plus")
                    }
                    Button(action: { showingHomeKitImport = true }) {
                        Label("Import from Home", systemImage: "house")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddZone) {
            AddZoneSheet()
        }
        .sheet(isPresented: $showingHomeKitImport) {
            HomeKitImportSheet()
        }
    }

    private func deleteZones(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(zones[index])
        }
    }
}

private struct ZoneRowView: View {
    let zone: Zone

    var body: some View {
        HStack(spacing: 12) {
            ZoneIcon(iconName: zone.icon, colorName: zone.color, size: 32)
                .frame(width: 40, height: 40)
                .background(ColorPalette.from(zone.color).color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(zone.name)
                    .font(.headline)
                if !zone.locationDescription.isEmpty {
                    Text(zone.locationDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(zone.bins.count) bins")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct AddZoneSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var locationDescription = ""
    @State private var selectedColor = ""
    @State private var selectedIcon = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Zone Name", text: $name)
                }

                Section("Description") {
                    TextField("Description (optional)", text: $locationDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Color") {
                    ColorPickerRow(selectedColor: $selectedColor)
                }

                Section("Icon") {
                    IconPickerGrid(selectedIcon: $selectedIcon)
                }
            }
            .navigationTitle("New Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addZone() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addZone() {
        let zone = Zone(
            name: name.trimmingCharacters(in: .whitespaces),
            locationDescription: locationDescription,
            color: selectedColor,
            icon: selectedIcon
        )
        modelContext.insert(zone)
        dismiss()
    }
}

struct HomeKitImportSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Zone.name) private var existingZones: [Zone]

    @State private var homeKitService = HomeKitService()
    @State private var selectedRooms = Set<String>()

    private var availableRooms: [String] {
        let existingNames = Set(existingZones.map { $0.name.lowercased() })
        return homeKitService.rooms.filter { !existingNames.contains($0.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if homeKitService.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Reading rooms from HomeKit...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = homeKitService.error {
                    ContentUnavailableView(
                        "Can't Access Home",
                        systemImage: "house.slash",
                        description: Text(error)
                    )
                } else if availableRooms.isEmpty {
                    ContentUnavailableView(
                        "No New Rooms",
                        systemImage: "checkmark.circle",
                        description: Text(
                            homeKitService.rooms.isEmpty
                                ? "No rooms found in HomeKit. Set up rooms in the Home app first."
                                : "All HomeKit rooms are already zones."
                        )
                    )
                } else {
                    List(availableRooms, id: \.self) { room in
                        HStack {
                            Text(room)
                            Spacer()
                            if selectedRooms.contains(room) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedRooms.contains(room) {
                                selectedRooms.remove(room)
                            } else {
                                selectedRooms.insert(room)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import Rooms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import (\(selectedRooms.count))") { importRooms() }
                        .disabled(selectedRooms.isEmpty)
                }
            }
            .task {
                await homeKitService.fetchRooms()
            }
        }
    }

    private func importRooms() {
        for roomName in selectedRooms {
            let zone = Zone(name: roomName, icon: "house")
            modelContext.insert(zone)
        }
        dismiss()
    }
}
