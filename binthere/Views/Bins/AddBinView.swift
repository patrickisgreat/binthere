import SwiftUI
import SwiftData

struct AddBinView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Zone.name) private var zones: [Zone]

    @State private var step: CreationStep = .details
    @State private var name = ""
    @State private var binDescription = ""
    @State private var location = ""
    @State private var selectedZone: Zone?
    @State private var createdBin: Bin?
    @State private var contentPhoto: UIImage?
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var analysisService = ImageAnalysisService()
    @State private var hasAnalyzed = false
    @State private var showingAddItem = false

    enum CreationStep {
        case details
        case qrAndPhoto
        case aiResults
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .details:
                    detailsStep
                case .qrAndPhoto:
                    qrAndPhotoStep
                case .aiResults:
                    aiResultsStep
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step == .details {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    confirmButton
                }
            }
        }
    }

    private var navigationTitle: String {
        switch step {
        case .details: "New Bin"
        case .qrAndPhoto: "Set Up Bin"
        case .aiResults: "Add Items"
        }
    }

    // MARK: - Step 1: Details

    private var detailsStep: some View {
        Form {
            Section("What's this bin?") {
                TextField("Bin Name", text: $name)
                TextField("Description (optional)", text: $binDescription, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Location (optional)", text: $location)
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
    }

    // MARK: - Step 2: QR Code + Photo

    private var qrAndPhotoStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                // QR Code section
                if let bin = createdBin {
                    qrCodeSection(for: bin)
                }

                Divider()
                    .padding(.horizontal)

                // Photo section
                photoSection
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingCamera) {
            ImagePickerView(selectedImage: $contentPhoto, sourceType: .camera)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(selectedImage: $contentPhoto, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showingAddItem) {
            if let bin = createdBin {
                AddItemView(bin: bin)
            }
        }
    }

    private func qrCodeSection(for bin: Bin) -> some View {
        VStack(spacing: 12) {
            Text("Your QR Code")
                .font(.headline)

            if let qrPath = bin.qrCodeImagePath,
               let qrImage = ImageStorageService.loadImage(filename: qrPath) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)

                HStack(spacing: 16) {
                    ShareLink(
                        item: Image(uiImage: qrImage),
                        preview: SharePreview("QR Code: \(bin.name)", image: Image(uiImage: qrImage))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    Button(action: { printQRCode(qrImage) }) {
                        Label("Print", systemImage: "printer")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Text("Stick it on your bin so you can scan it later")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func printQRCode(_ image: UIImage) {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "QR Code: \(name)"
        printInfo.outputType = .photo

        let printer = UIPrintInteractionController.shared
        printer.printInfo = printInfo
        printer.printingItem = image
        printer.present(animated: true)
    }

    private var photoSection: some View {
        VStack(spacing: 16) {
            Text("Photo of Contents")
                .font(.headline)

            Text("Take a photo of what's in the bin. AI can identify items for you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let photo = contentPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                HStack(spacing: 16) {
                    Button("Retake") {
                        contentPhoto = nil
                    }
                    .buttonStyle(.bordered)

                    Button("Analyze with AI") {
                        analyzePhoto()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                HStack(spacing: 16) {
                    Button(action: { showingCamera = true }) {
                        Label("Camera", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: { showingImagePicker = true }) {
                        Label("Library", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            }

            Divider()
                .padding(.horizontal)

            Button(action: { showingAddItem = true }) {
                Label("Add Items Manually", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
    }

    // MARK: - Step 3: AI Results

    private var aiResultsStep: some View {
        Group {
            if analysisService.isAnalyzing {
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Analyzing your bin contents...")
                        .font(.headline)
                    Text("AI is identifying items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if let error = analysisService.error {
                VStack(spacing: 16) {
                    Spacer()
                    ContentUnavailableView(
                        "Analysis Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription)
                    )
                    Button("Try Again") { analyzePhoto() }
                        .buttonStyle(.bordered)
                    Button("Skip — I'll add items manually") { dismiss() }
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    Section {
                        Text("Review what AI found. Edit or deselect anything that's off.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach($analysisService.suggestedItems) { $suggestion in
                        SuggestedItemRow(suggestion: $suggestion)
                    }
                }
            }
        }
    }

    // MARK: - Confirm Button

    @ViewBuilder
    private var confirmButton: some View {
        switch step {
        case .details:
            Button("Create Bin") { createBin() }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        case .qrAndPhoto:
            Button("Done") { dismiss() }
        case .aiResults:
            if !analysisService.isAnalyzing {
                Button("Save Items") { saveItemsAndFinish() }
                    .disabled(!analysisService.suggestedItems.contains(where: \.isSelected))
            }
        }
    }

    // MARK: - Actions

    private func createBin() {
        let bin = Bin(
            name: name.trimmingCharacters(in: .whitespaces),
            binDescription: binDescription,
            location: location
        )
        bin.zone = selectedZone

        // Generate and store QR code
        if let qrImage = QRGeneratorService.generateQRCode(from: bin.id.uuidString),
           let qrPath = ImageStorageService.saveImage(qrImage) {
            bin.qrCodeImagePath = qrPath
        }

        modelContext.insert(bin)
        createdBin = bin
        step = .qrAndPhoto
    }

    private func analyzePhoto() {
        guard let photo = contentPhoto else { return }

        // Save the content photo to the bin
        if let bin = createdBin, let path = ImageStorageService.saveImage(photo) {
            bin.contentImagePaths.append(path)
        }

        step = .aiResults
        hasAnalyzed = true

        Task {
            await analysisService.analyzeImage(photo)
        }
    }

    private func saveItemsAndFinish() {
        guard let bin = createdBin else {
            dismiss()
            return
        }

        let contentImagePath = bin.contentImagePaths.first

        for suggestion in analysisService.suggestedItems where suggestion.isSelected {
            let item = Item(
                name: suggestion.name,
                itemDescription: suggestion.description,
                bin: bin
            )
            item.tags = suggestion.tags
            if let path = contentImagePath {
                item.imagePaths = [path]
            }
            modelContext.insert(item)
        }

        dismiss()
    }
}

private struct SuggestedItemRow: View {
    @Binding var suggestion: SuggestedItem

    var body: some View {
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
                if !suggestion.tags.isEmpty {
                    Text(suggestion.tags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .opacity(suggestion.isSelected ? 1 : 0.5)
        .padding(.vertical, 4)
    }
}
