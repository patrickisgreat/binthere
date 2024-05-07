import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var item = Item(timestamp: Date())
    @State private var isImagePickerShowing = false
    @State private var pickedImage: UIImage?

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
                ToolbarItem {
                    Button("Pick Image") {
                        isImagePickerShowing = true
                    }
                }
            }
            .sheet(isPresented: $isImagePickerShowing) {
                ImagePickerView(selectedImage: $pickedImage)
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            if let image = pickedImage {
                // Save the image to the file system and get the path
                let imagePath = saveImage(image: image)
                newItem.imagePath = imagePath
            }
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }

    private func saveImage(image: UIImage) -> String {
        // Implement saving image to the file system and returning the path
        // Placeholder function: Please implement based on your file management strategy
        return "/path/to/image"
    }
}
