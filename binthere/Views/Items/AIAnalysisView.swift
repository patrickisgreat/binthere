import SwiftUI

struct AIAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let bin: Bin

    @State private var analysisService = ImageAnalysisService()
    @State private var capturedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var hasAnalyzed = false

    var body: some View {
        NavigationStack {
            Group {
                if analysisService.isAnalyzing {
                    analysisLoadingView
                } else if hasAnalyzed {
                    resultsView
                } else {
                    captureView
                }
            }
            .navigationTitle("AI Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var captureView: some View {
        VStack(spacing: 24) {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                Button("Analyze with AI") {
                    Task {
                        hasAnalyzed = true
                        await analysisService.analyzeImage(image)
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Retake Photo") {
                    capturedImage = nil
                }
            } else {
                Spacer()

                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.opacity(0.6))

                Text("Take a photo of your bin's contents")
                    .font(.title3)
                    .multilineTextAlignment(.center)

                Text("AI will identify the items and suggest names, descriptions, and tags for each one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: { showingCamera = true }) {
                        Label("Take Photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: { showingImagePicker = true }) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePickerView(selectedImage: $capturedImage, sourceType: .camera)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(selectedImage: $capturedImage, sourceType: .photoLibrary)
        }
    }

    private var analysisLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing image...")
                .font(.headline)
            Text("AI is identifying items in your bin")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var resultsView: some View {
        VStack {
            if let error = analysisService.error {
                ContentUnavailableView(
                    "Analysis Failed",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
                .padding()

                Button("Try Again") {
                    hasAnalyzed = false
                    analysisService.error = nil
                }
                .buttonStyle(.bordered)
            } else if analysisService.suggestedItems.isEmpty {
                ContentUnavailableView(
                    "No Items Found",
                    systemImage: "magnifyingglass",
                    description: Text("AI couldn't identify distinct items. Try a clearer photo.")
                )

                Button("Try Again") {
                    hasAnalyzed = false
                }
                .buttonStyle(.bordered)
            } else {
                List {
                    Section {
                        Text("Review the items AI found. Edit or deselect any that aren't right.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach($analysisService.suggestedItems) { $suggestion in
                        SuggestedItemRow(suggestion: $suggestion)
                    }

                    Section {
                        Button("Save Selected Items") {
                            saveSelectedItems()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(!analysisService.suggestedItems.contains(where: \.isSelected))
                    }
                }
            }
        }
    }

    private func saveSelectedItems() {
        let imagePath: String? = capturedImage.flatMap { ImageStorageService.saveImage($0) }

        for suggestion in analysisService.suggestedItems where suggestion.isSelected {
            let item = Item(
                name: suggestion.name,
                itemDescription: suggestion.description,
                bin: bin
            )
            item.tags = suggestion.tags
            item.color = suggestion.color
            item.householdId = bin.householdId
            item.updatedAt = Date()
            if let value = suggestion.value {
                item.value = value
                item.valueSource = "ai"
                item.valueUpdatedAt = Date()
            }
            if let path = imagePath {
                item.imagePaths = [path]
            }
            modelContext.insert(item)
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct SuggestedItemRow: View {
    @Binding var suggestion: SuggestedItem
    @State private var expanded = false
    @State private var valueText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Toggle("", isOn: $suggestion.isSelected)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Name", text: $suggestion.name)
                        .font(.headline)
                    TextField("Description", text: $suggestion.description, axis: .vertical)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2...4)
                }

                Spacer(minLength: 0)

                Button(action: { withAnimation { expanded.toggle() } }) {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Tags")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                        TextField("Comma separated", text: Binding(
                            get: { suggestion.tagsText },
                            set: { suggestion.tagsText = $0 }
                        ))
                        .font(.caption)
                    }

                    HStack {
                        Text("Color")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                        ColorPickerRow(selectedColor: $suggestion.color)
                    }

                    HStack {
                        Text("Value")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $valueText)
                            .font(.caption)
                            .keyboardType(.decimalPad)
                            .onChange(of: valueText) { _, newValue in
                                suggestion.value = Double(newValue.filter { $0.isNumber || $0 == "." })
                            }
                    }
                }
                .padding(.leading, 40)
                .transition(.opacity)
            }
        }
        .opacity(suggestion.isSelected ? 1 : 0.5)
        .padding(.vertical, 4)
        .onAppear {
            if let val = suggestion.value {
                valueText = String(format: "%.2f", val)
            }
        }
    }
}
