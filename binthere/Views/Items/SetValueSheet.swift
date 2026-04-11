import SwiftUI

struct SetValueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: Item

    @State private var valueText: String = ""
    @State private var reasoning: String = ""
    @State private var analysisService = ImageAnalysisService()
    @State private var isEstimating = false

    private var canEstimate: Bool {
        ImageAnalysisService.apiKey != nil
            && !(ImageAnalysisService.apiKey ?? "").isEmpty
            && !item.imagePaths.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Value") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $valueText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Button(action: estimateWithAI) {
                        HStack {
                            if isEstimating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(isEstimating ? "Estimating..." : "Estimate with AI")
                        }
                    }
                    .disabled(!canEstimate || isEstimating)

                    if !canEstimate {
                        Text(item.imagePaths.isEmpty
                             ? "Add a photo to use AI estimation"
                             : "Add your Claude API key in Settings to use AI estimation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !reasoning.isEmpty {
                    Section("AI Reasoning") {
                        Text(reasoning)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = analysisService.error {
                    Section {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Set Value")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(CurrencyFormatter.parse(valueText) == nil)
                }
            }
            .onAppear {
                if let existing = item.value {
                    valueText = String(format: "%.2f", existing)
                }
            }
        }
    }

    private func estimateWithAI() {
        guard let photo = item.imagePaths.first.flatMap({ ImageStorageService.loadImage(filename: $0) }) else {
            return
        }

        isEstimating = true
        Task {
            let estimate = await analysisService.estimateValue(
                for: photo,
                itemName: item.name,
                itemDescription: item.itemDescription
            )
            isEstimating = false
            if let estimate {
                valueText = String(format: "%.2f", estimate.value)
                reasoning = estimate.reasoning
                item.valueSource = "ai"
            }
        }
    }

    private func save() {
        guard let value = CurrencyFormatter.parse(valueText) else { return }
        item.value = value
        item.valueUpdatedAt = Date()
        if item.valueSource.isEmpty {
            item.valueSource = "manual"
        }
        dismiss()
    }
}
