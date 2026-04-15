import SwiftUI
import SwiftData

struct BulkValuationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let title: String
    let items: [Item]

    @State private var analysisService = ImageAnalysisService()
    @State private var phase: Phase = .review
    @State private var estimates: [UUID: ImageAnalysisService.BulkValueResult] = [:]
    @State private var acceptedIds: Set<UUID> = []
    @State private var task: Task<Void, Never>?

    enum Phase {
        case review     // pre-estimate: show items, "Estimate" button
        case estimating
        case results    // show estimates, allow accept/reject per item
        case done
    }

    private var itemsWithoutValue: [Item] {
        items.filter { $0.value == nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .review:
                    reviewView
                case .estimating:
                    estimatingView
                case .results:
                    resultsView
                case .done:
                    doneView
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        task?.cancel()
                        dismiss()
                    }
                }
                if phase == .results {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { applyAccepted() }
                            .disabled(acceptedIds.isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Phases

    private var reviewView: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    Text(
                        "AI will estimate the resale value for the items below in a single batch. " +
                        "You'll review and accept each estimate before it's saved."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("Items (\(itemsWithoutValue.count))") {
                    if itemsWithoutValue.isEmpty {
                        Text("All items already have values set. Cancel to dismiss, or run anyway to overwrite.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(items) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text(CurrencyFormatter.format(item.value))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        ForEach(itemsWithoutValue) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                if !item.itemDescription.isEmpty {
                                    Text(item.itemDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }

            Button(action: startEstimation) {
                Label("Estimate Values with AI", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    private var estimatingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Estimating values...")
                .font(.headline)
            Text("AI is reviewing \(itemsToEstimate().count) items")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()

            Button("Cancel") {
                task?.cancel()
                phase = .review
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 32)
        }
    }

    private var resultsView: some View {
        Group {
            if let error = analysisService.error {
                ContentUnavailableView(
                    "Estimation Failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else if estimates.isEmpty {
                ContentUnavailableView(
                    "No Estimates",
                    systemImage: "questionmark.circle",
                    description: Text("AI didn't return any estimates.")
                )
            } else {
                List {
                    Section {
                        Text("Tap items to toggle. Saved values use \"AI\" as the source.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(itemsToEstimate()) { item in
                        if let estimate = estimates[item.id] {
                            estimateRow(item: item, estimate: estimate)
                        }
                    }
                }
            }
        }
    }

    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("Values Saved")
                .font(.title2.bold())
            Text("\(acceptedIds.count) item\(acceptedIds.count == 1 ? "" : "s") updated")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 32)
        }
    }

    private func estimateRow(item: Item, estimate: ImageAnalysisService.BulkValueResult) -> some View {
        Button(action: { toggle(item.id) }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: acceptedIds.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(acceptedIds.contains(item.id) ? Color.green : .secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(CurrencyFormatter.format(estimate.value))
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                    if !estimate.reasoning.isEmpty {
                        Text(estimate.reasoning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func itemsToEstimate() -> [Item] {
        itemsWithoutValue.isEmpty ? items : itemsWithoutValue
    }

    private func toggle(_ id: UUID) {
        if acceptedIds.contains(id) {
            acceptedIds.remove(id)
        } else {
            acceptedIds.insert(id)
        }
    }

    private func startEstimation() {
        let targets = itemsToEstimate()
        let inputs = targets.map {
            ImageAnalysisService.BulkValueInput(
                id: $0.id,
                name: $0.name,
                description: $0.itemDescription
            )
        }
        phase = .estimating
        task = Task {
            let results = await analysisService.estimateValuesBulk(items: inputs)
            await MainActor.run {
                estimates = results
                acceptedIds = Set(results.keys)
                phase = .results
            }
        }
    }

    private func applyAccepted() {
        for item in itemsToEstimate() {
            guard acceptedIds.contains(item.id),
                  let estimate = estimates[item.id] else { continue }
            item.value = estimate.value
            item.valueSource = "ai"
            item.valueUpdatedAt = Date()
            item.updatedAt = Date()
        }
        try? modelContext.save()
        phase = .done
    }
}
