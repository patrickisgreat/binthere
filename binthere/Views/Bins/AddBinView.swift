import SwiftUI
import SwiftData

struct AddBinView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HouseholdService.self) private var householdService
    @Environment(SyncService.self) private var syncService
    @Query(sort: \Zone.name) private var zones: [Zone]
    @Query private var allBins: [Bin]

    @State private var step: CreationStep = .details
    @State private var label = ""
    @State private var binDescription = ""
    @State private var location = ""
    @State private var selectedColor = ""
    @State private var selectedZone: Zone?
    @State private var createdBin: Bin?
    @State private var contentPhoto: UIImage?
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var showingAddItem = false
    @State private var nfcService = NFCService()
    @State private var analysisService = ImageAnalysisService()
    @State private var hasAnalyzed = false

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
            Section("Label (optional)") {
                TextField("e.g. Garage Shelf, Junk Drawer", text: $label)
            }

            Section("Where is it?") {
                Picker("Zone", selection: $selectedZone) {
                    Text("None").tag(nil as Zone?)
                    ForEach(zones) { zone in
                        Label {
                            Text(zone.name)
                        } icon: {
                            ZoneIcon(iconName: zone.icon, colorName: zone.color)
                        }
                        .tag(zone as Zone?)
                    }
                }
                TextField("Location (optional)", text: $location)
            }

            Section("Color") {
                ColorPickerRow(selectedColor: $selectedColor)
            }

            Section("Description") {
                TextField("What's in this bin? (optional)", text: $binDescription, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
    }

    // MARK: - Step 2: QR Code + Photo

    private var qrAndPhotoStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let bin = createdBin {
                    qrLabelSection(for: bin)
                }

                Divider()
                    .padding(.horizontal)

                photoSection

                Divider()
                    .padding(.horizontal)

                addedItemsSection
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

    private func qrLabelSection(for bin: Bin) -> some View {
        VStack(spacing: 12) {
            Text(bin.code)
                .font(.system(size: 36, weight: .bold, design: .monospaced))

            if let labelImage = QRGeneratorService.generateQRLabel(code: bin.code, binID: bin.id.uuidString) {
                Image(uiImage: labelImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)

                HStack(spacing: 16) {
                    ShareLink(
                        item: Image(uiImage: labelImage),
                        preview: SharePreview("Bin \(bin.code)", image: Image(uiImage: labelImage))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)

                    Button(action: { printLabel(labelImage) }) {
                        Label("Print", systemImage: "printer")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Button(action: { nfcService.writeTag(binID: bin.id.uuidString) }) {
                Label("Write NFC Tag", systemImage: "wave.3.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text("Print a label, share it, or write an NFC tag")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func printLabel(_ image: UIImage) {
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Bin \(createdBin?.code ?? "")"
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
                    Button("Retake") { contentPhoto = nil }
                        .buttonStyle(.bordered)

                    Button("Analyze with AI") { analyzePhoto() }
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
        }
    }

    private var addedItemsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Items")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddItem = true }) {
                    Label("Add Item", systemImage: "plus.circle")
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)

            if let bin = createdBin, !bin.items.isEmpty {
                ForEach(bin.items.sorted(by: { $0.createdAt < $1.createdAt })) { item in
                    HStack(spacing: 12) {
                        ColorDot(colorName: item.color, size: 12)
                        Text(item.name)
                            .font(.subheadline)
                        Spacer()
                        if !item.tags.isEmpty {
                            Text(item.tags.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }
            } else {
                Text("No items added yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
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
        let existingCodes = Set(allBins.map(\.code))
        let code = CodeGenerator.generateCode(existingCodes: existingCodes)
        let householdId = householdService.currentHouseholdId

        let bin = Bin(
            code: code,
            name: label.trimmingCharacters(in: .whitespaces),
            binDescription: binDescription,
            location: location
        )
        bin.zone = selectedZone
        bin.color = selectedColor
        bin.householdId = householdId
        bin.updatedAt = Date()

        if let labelImage = QRGeneratorService.generateQRLabel(code: code, binID: bin.id.uuidString),
           let labelPath = ImageStorageService.saveImage(labelImage) {
            bin.qrCodeImagePath = labelPath
        }

        modelContext.insert(bin)

        // Force save so @Query observers update
        do {
            try modelContext.save()
        } catch {
            print("Failed to save bin: \(error)")
        }

        // Push to Supabase
        if !householdId.isEmpty {
            Task {
                try? await syncService.pushBin(bin, householdId: householdId)
            }
        }

        createdBin = bin
        step = .qrAndPhoto
    }

    private func analyzePhoto() {
        guard let photo = contentPhoto else { return }

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
            item.color = suggestion.color
            item.householdId = bin.householdId
            item.updatedAt = Date()
            if let value = suggestion.value {
                item.value = value
                item.valueSource = "ai"
                item.valueUpdatedAt = Date()
            }
            if let path = contentImagePath {
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
