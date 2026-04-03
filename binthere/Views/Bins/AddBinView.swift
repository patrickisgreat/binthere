import SwiftUI
import SwiftData

struct AddBinView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Zone.name) private var zones: [Zone]

    @State private var name = ""
    @State private var binDescription = ""
    @State private var location = ""
    @State private var selectedZone: Zone?

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Bin Name", text: $name)
                    TextField("Description", text: $binDescription, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Location", text: $location)
                }

                Section("Zone") {
                    Picker("Zone", selection: $selectedZone) {
                        Text("None").tag(nil as Zone?)
                        ForEach(zones) { zone in
                            Text(zone.name).tag(zone as Zone?)
                        }
                    }
                }
            }
            .navigationTitle("New Bin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveBin() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveBin() {
        let bin = Bin(name: name.trimmingCharacters(in: .whitespaces),
                      binDescription: binDescription,
                      location: location)
        bin.zone = selectedZone
        modelContext.insert(bin)
        dismiss()
    }
}
