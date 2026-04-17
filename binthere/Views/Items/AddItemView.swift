import SwiftUI

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService

    let bin: Bin

    @State private var name = ""
    @State private var itemDescription = ""
    @State private var tagsText = ""
    @State private var selectedColor = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Item Name", text: $name)
                    TextField("Description", text: $itemDescription, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Tags (comma separated)", text: $tagsText)
                }

                Section("Color") {
                    ColorPickerRow(selectedColor: $selectedColor)
                }

                Section("Photo") {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button("Remove Photo", role: .destructive) {
                            selectedImage = nil
                        }
                    }

                    Button(action: { showingCamera = true }) {
                        Label("Take Photo", systemImage: "camera")
                    }
                    Button(action: { showingImagePicker = true }) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                }

                Section {
                    Text("Adding to: \(bin.name)")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(selectedImage: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showingCamera) {
                ImagePickerView(selectedImage: $selectedImage, sourceType: .camera)
            }
        }
    }

    private func saveItem() {
        let item = Item(
            name: name.trimmingCharacters(in: .whitespaces),
            itemDescription: itemDescription,
            bin: bin
        )

        item.color = selectedColor
        item.createdBy = authService.currentUserId ?? ""

        if !tagsText.isEmpty {
            item.tags = tagsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        if let image = selectedImage, let filename = ImageStorageService.saveImage(image) {
            item.imagePaths = [filename]
        }

        modelContext.insert(item)
        dismiss()
    }
}
