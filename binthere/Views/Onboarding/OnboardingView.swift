import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HouseholdService.self) private var householdService
    @Environment(SyncService.self) private var syncService

    let onComplete: () -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var selectedPresets: Set<String> = []
    @State private var customZoneName = ""

    enum OnboardingStep {
        case welcome
        case zones
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index <= stepIndex ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)

            TabView(selection: $step) {
                welcomeStep
                    .tag(OnboardingStep.welcome)

                zonesStep
                    .tag(OnboardingStep.zones)

                doneStep
                    .tag(OnboardingStep.done)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: step)
        }
    }

    private var stepIndex: Int {
        switch step {
        case .welcome: return 0
        case .zones: return 1
        case .done: return 2
        }
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "party.popper")
                .font(.system(size: 60))
                .foregroundStyle(.blue.opacity(0.6))

            Text("Welcome to binthere!")
                .font(.title2.weight(.bold))

            if let name = householdService.currentHousehold?.name {
                Text("\"\(name)\" is ready to go.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Let's set up some zones so you can organize your bins by location — like rooms, closets, or storage areas.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                Button(action: { step = .zones }) {
                    Text("Set Up Zones")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 20)
                }
                .buttonStyle(.borderedProminent)

                Button("Skip for Now") {
                    onComplete()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Zones Step

    private var zonesStep: some View {
        VStack(spacing: 20) {
            Text("Add Zones")
                .font(.title2.weight(.bold))
                .padding(.top, 20)

            Text("Tap to select common zones, or add your own.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    ForEach(ZonePreset.allPresets, id: \.name) { preset in
                        ZonePresetCard(
                            preset: preset,
                            isSelected: selectedPresets.contains(preset.name)
                        ) {
                            if selectedPresets.contains(preset.name) {
                                selectedPresets.remove(preset.name)
                            } else {
                                selectedPresets.insert(preset.name)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Custom zone input
                HStack {
                    TextField("Custom zone name…", text: $customZoneName)
                        .padding()
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        let name = customZoneName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        selectedPresets.insert(name)
                        customZoneName = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(customZoneName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            VStack(spacing: 12) {
                Button(action: {
                    createSelectedZones()
                    step = .done
                }) {
                    Text(selectedPresets.isEmpty
                        ? "Continue Without Zones"
                        : "Create \(selectedPresets.count) Zone\(selectedPresets.count == 1 ? "" : "s")")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 20)
                }
                .buttonStyle(.borderedProminent)

                Button("Back") { step = .welcome }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Done Step

    private var doneStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title2.weight(.bold))

            VStack(spacing: 8) {
                if !selectedPresets.isEmpty {
                    Text("Created \(selectedPresets.count) zone\(selectedPresets.count == 1 ? "" : "s").")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Start by adding your first bin — give it a label, pick a zone, and you're organizing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button(action: onComplete) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 20)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Actions

    private func createSelectedZones() {
        let householdId = householdService.currentHouseholdId
        for presetName in selectedPresets {
            let preset = ZonePreset.allPresets.first { $0.name == presetName }
            let zone = Zone(
                name: presetName,
                locationDescription: preset?.description ?? "",
                color: preset?.color ?? "",
                icon: preset?.icon ?? ""
            )
            zone.householdId = householdId
            zone.updatedAt = Date()
            modelContext.insert(zone)
        }
        try? modelContext.save()

        if !householdId.isEmpty {
            Task {
                let descriptor = FetchDescriptor<Zone>()
                if let zones = try? modelContext.fetch(descriptor) {
                    for zone in zones where zone.householdId == householdId {
                        try? await syncService.pushZone(zone, householdId: householdId)
                    }
                }
            }
        }
    }
}

// MARK: - Zone Presets

struct ZonePreset {
    let name: String
    let description: String
    let icon: String
    let color: String

    static let allPresets: [Self] = [
        Self(name: "Garage", description: "Tools, outdoor gear, automotive", icon: "car.fill", color: "orange"),
        Self(name: "Kitchen", description: "Pantry, cabinets, drawers", icon: "fork.knife", color: "green"),
        Self(name: "Bedroom", description: "Closets, under-bed storage", icon: "bed.double.fill", color: "blue"),
        Self(name: "Living Room", description: "Shelves, entertainment center", icon: "sofa.fill", color: "purple"),
        Self(name: "Basement", description: "Long-term storage, seasonal items", icon: "arrow.down.square.fill", color: "gray"),
        Self(name: "Attic", description: "Holiday decorations, keepsakes", icon: "triangle.fill", color: "yellow"),
        Self(name: "Office", description: "Supplies, electronics, files", icon: "desktopcomputer", color: "cyan"),
        Self(name: "Bathroom", description: "Cabinets, under-sink storage", icon: "shower.fill", color: "teal"),
        Self(name: "Closet", description: "Clothes, shoes, accessories", icon: "tshirt.fill", color: "pink"),
        Self(name: "Storage Unit", description: "Off-site storage facility", icon: "building.2.fill", color: "brown"),
        Self(name: "Shed", description: "Garden tools, outdoor equipment", icon: "house.fill", color: "mint"),
        Self(name: "Workshop", description: "Power tools, workbench, supplies", icon: "wrench.and.screwdriver.fill", color: "red"),
    ]
}

// MARK: - Preset Card

private struct ZonePresetCard: View {
    let preset: ZonePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : ColorPalette.from(preset.color).color)

                Text(preset.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected
                ? ColorPalette.from(preset.color).color
                : ColorPalette.from(preset.color).color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
