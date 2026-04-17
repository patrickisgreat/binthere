import SwiftUI
import SwiftData

struct CheckedOutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Item> { $0.isCheckedOut }, sort: \Item.updatedAt, order: .reverse)
    private var checkedOutItems: [Item]

    @State private var showingCheckoutItem: Item?

    var body: some View {
        Group {
            if checkedOutItems.isEmpty {
                ContentUnavailableView(
                    "Nothing Checked Out",
                    systemImage: "checkmark.circle",
                    description: Text("All items are in their bins. Check out an item from a bin to track it here.")
                )
            } else {
                List {
                    Section {
                        Text("\(checkedOutItems.count) item\(checkedOutItems.count == 1 ? "" : "s") currently out")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(overdueItems) { item in
                        CheckedOutItemRow(item: item, isOverdue: true)
                            .swipeActions(edge: .leading) {
                                Button("Check In") { checkIn(item) }
                                    .tint(.green)
                            }
                    }

                    if !onTimeItems.isEmpty {
                        Section(overdueItems.isEmpty ? "" : "On Time") {
                            ForEach(onTimeItems) { item in
                                CheckedOutItemRow(item: item, isOverdue: false)
                                    .swipeActions(edge: .leading) {
                                        Button("Check In") { checkIn(item) }
                                            .tint(.green)
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Checked Out")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var overdueItems: [Item] {
        checkedOutItems.filter { item in
            guard let record = item.checkoutHistory.first(where: { $0.isActive }),
                  let dueDate = record.expectedReturnDate else { return false }
            return dueDate < Date()
        }
    }

    private var onTimeItems: [Item] {
        checkedOutItems.filter { item in
            guard let record = item.checkoutHistory.first(where: { $0.isActive }) else { return true }
            guard let dueDate = record.expectedReturnDate else { return true }
            return dueDate >= Date()
        }
    }

    private func checkIn(_ item: Item) {
        if let record = item.checkoutHistory.first(where: { $0.isActive }) {
            record.checkedInAt = Date()
        }
        item.isCheckedOut = false
        item.updatedAt = Date()
        NotificationService.cancelDueBackReminders(for: item.id)
    }
}

private struct CheckedOutItemRow: View {
    let item: Item
    let isOverdue: Bool

    private var activeRecord: CheckoutRecord? {
        item.checkoutHistory.first(where: { $0.isActive })
    }

    var body: some View {
        NavigationLink(value: item) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.name)
                        .font(.headline)
                    Spacer()
                    if isOverdue {
                        Text("OVERDUE")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.2))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }

                if let record = activeRecord {
                    Label(record.checkedOutTo, systemImage: "person")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label("Out \(record.checkedOutAt, style: .relative) ago",
                              systemImage: "clock")
                        if let dueDate = record.expectedReturnDate {
                            Label("Due \(dueDate, style: .date)", systemImage: "calendar")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(isOverdue ? .red : .secondary)
                }

                if let bin = item.bin {
                    Label(bin.displayName, systemImage: "archivebox")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
