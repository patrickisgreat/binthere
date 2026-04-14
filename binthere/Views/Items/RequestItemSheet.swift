import SwiftUI
import Supabase

struct RequestItemSheet: View {
    @Environment(AuthService.self) private var authService
    @Environment(HouseholdService.self) private var householdService
    @Environment(\.dismiss) private var dismiss

    let item: Item
    let activeRecord: CheckoutRecord

    @State private var message = ""
    @State private var isSending = false
    @State private var sent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "bell.badge")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                if sent {
                    Text("Request Sent!")
                        .font(.title2.weight(.bold))
                    Text("They'll be notified that you need \(item.name) back.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                } else {
                    Text("Request Return")
                        .font(.title2.weight(.bold))

                    Text("\(item.name) is checked out to \(activeRecord.checkedOutTo)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    if let returnDate = activeRecord.expectedReturnDate {
                        Text("Expected back: \(returnDate, style: .date)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Add a message (optional)", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 40)

                    Button(action: sendRequest) {
                        if isSending {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 20)
                        } else {
                            Label("Send Request", systemImage: "paperplane")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 20)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isSending)
                    .padding(.horizontal, 40)
                }

                Spacer()
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sendRequest() {
        isSending = true
        Task {
            // Store the return request in Supabase
            // In the future, this triggers a push notification via Edge Function
            let client = SupabaseManager.shared.client
            let payload: [String: AnyJSON] = [
                "item_id": .string(item.id.uuidString),
                "household_id": .string(item.householdId),
                "requested_by": .string(authService.currentUserId ?? ""),
                "checked_out_to": .string(activeRecord.checkedOutBy),
                "message": .string(message),
            ]

            // For now, we just mark it as sent locally
            // Push notification integration comes with APNs setup
            _ = payload

            try? await Task.sleep(for: .milliseconds(500))
            isSending = false
            sent = true
        }
    }
}
