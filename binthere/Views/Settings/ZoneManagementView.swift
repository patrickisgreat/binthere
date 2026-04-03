import SwiftUI
import SwiftData

struct ZoneManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Zone.name) private var zones: [Zone]
    @State private var showingAddZone = false
    @State private var newZoneName = ""
    @State private var newZoneDescription = ""

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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(zone.name)
                            .font(.headline)
                        if !zone.locationDescription.isEmpty {
                            Text(zone.locationDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(zone.bins.count) bins")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete(perform: deleteZones)
            }
        }
        .navigationTitle("Zones")
        .toolbar {
            Button(action: { showingAddZone = true }) {
                Label("Add Zone", systemImage: "plus")
            }
        }
        .alert("New Zone", isPresented: $showingAddZone) {
            TextField("Zone Name", text: $newZoneName)
            TextField("Description (optional)", text: $newZoneDescription)
            Button("Add") { addZone() }
            Button("Cancel", role: .cancel) {
                newZoneName = ""
                newZoneDescription = ""
            }
        }
    }

    private func addZone() {
        guard !newZoneName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let zone = Zone(
            name: newZoneName.trimmingCharacters(in: .whitespaces),
            locationDescription: newZoneDescription
        )
        modelContext.insert(zone)
        newZoneName = ""
        newZoneDescription = ""
    }

    private func deleteZones(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(zones[index])
        }
    }
}
