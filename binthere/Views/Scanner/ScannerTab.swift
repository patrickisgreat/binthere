import SwiftUI
import SwiftData
import CoreNFC

struct ScannerTab: View {
    @Environment(\.modelContext) private var modelContext
    @State private var scannedCode = ""
    @State private var scanMode: ScanMode = .qr
    @State private var showingNotFound = false
    @State private var showingCreateBin = false
    @State private var lastScannedID: UUID?
    @State private var nfcService = NFCService()
    @State private var foundBin: Bin?

    enum ScanMode: String, CaseIterable {
        case qr = "QR Code"
        case nfc = "NFC Tag"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Scan Mode", selection: $scanMode) {
                ForEach(ScanMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch scanMode {
                case .qr:
                    qrScannerView
                case .nfc:
                    nfcScannerView
                }
            }
            .frame(maxHeight: .infinity)
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Bin.self) { bin in
            BinDetailView(bin: bin)
        }
        .alert("Bin Not Found", isPresented: $showingNotFound) {
            Button("Create New Bin") { showingCreateBin = true }
            Button("Cancel", role: .cancel) {
                scannedCode = ""
            }
        } message: {
            Text("No bin matches this scan. Would you like to create one?")
        }
        .sheet(isPresented: $showingCreateBin) {
            AddBinView()
        }
        .onChange(of: nfcService.scannedBinID) { _, newValue in
            if let binID = newValue {
                handleScannedCode(binID)
            }
        }
        .onChange(of: nfcService.error) { _, _ in
            // NFC errors are shown by the system NFC sheet
        }
    }

    // MARK: - QR Scanner

    private var qrScannerView: some View {
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
        .onChange(of: scannedCode) { _, newValue in
            handleScannedCode(newValue)
        }
    }

    // MARK: - NFC Scanner

    private var nfcScannerView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wave.3.right")
                .font(.system(size: 80))
                .foregroundStyle(.blue.opacity(0.6))
                .symbolEffect(.pulse, isActive: true)

            Text("Scan NFC Tag")
                .font(.title2.weight(.semibold))

            Text("Hold your iPhone near a bin's NFC tag to see its contents.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { nfcService.startScanning() }) {
                Label("Scan NFC Tag", systemImage: "wave.3.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            if !NFCNDEFReaderSession.readingAvailable {
                Label("NFC is not available on this device", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Shared Lookup

    private func handleScannedCode(_ code: String) {
        guard !code.isEmpty, let uuid = UUID(uuidString: code) else { return }
        guard uuid != lastScannedID else { return }
        lastScannedID = uuid

        let descriptor = FetchDescriptor<Bin>(predicate: #Predicate { bin in
            bin.id == uuid
        })

        if let bin = try? modelContext.fetch(descriptor).first {
            foundBin = bin
        } else {
            showingNotFound = true
        }
    }
}
