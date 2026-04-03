import SwiftUI
import SwiftData

struct ScannerTab: View {
    @Environment(\.modelContext) private var modelContext
    @State private var scannedCode = ""
    @State private var navigationPath = NavigationPath()
    @State private var showingNotFound = false
    @State private var showingCreateBin = false
    @State private var lastScannedID: UUID?

    var body: some View {
        ZStack {
            QRScannerView(scannedCode: $scannedCode)
                .ignoresSafeArea()

            VStack {
                Spacer()
                Text("Point camera at a bin's QR code")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 40)
            }
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Bin.self) { bin in
            BinDetailView(bin: bin)
        }
        .onChange(of: scannedCode) { _, newValue in
            handleScannedCode(newValue)
        }
        .alert("Bin Not Found", isPresented: $showingNotFound) {
            Button("Create New Bin") { showingCreateBin = true }
            Button("Cancel", role: .cancel) {
                scannedCode = ""
            }
        } message: {
            Text("No bin matches this QR code. Would you like to create one?")
        }
        .sheet(isPresented: $showingCreateBin) {
            AddBinView()
        }
    }

    private func handleScannedCode(_ code: String) {
        guard !code.isEmpty, let uuid = UUID(uuidString: code) else { return }
        guard uuid != lastScannedID else { return }
        lastScannedID = uuid

        let descriptor = FetchDescriptor<Bin>(predicate: #Predicate { bin in
            bin.id == uuid
        })

        if let bin = try? modelContext.fetch(descriptor).first {
            navigationPath.append(bin)
        } else {
            showingNotFound = true
        }
    }
}
