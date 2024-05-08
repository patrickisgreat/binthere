// ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var items: [Item] = []  // This holds your items
    @State private var pickedImage: UIImage?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(items, id: \.id) { item in
                    Text("Item at \(item.timestamp, formatter: itemFormatter)")
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                Button("Add Item") {
                    addItem()
                }
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            newItem.insert()
            items.append(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.forEach { index in
                items[index].delete()
            }
            items.remove(atOffsets: offsets)
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .medium
    return formatter
}()
