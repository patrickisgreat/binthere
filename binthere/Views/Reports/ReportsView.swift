import SwiftUI
import SwiftData

struct ReportsView: View {
    @Query(sort: \Zone.name) private var zones: [Zone]
    @Query(sort: \Bin.code) private var bins: [Bin]

    @State private var selectedBin: Bin?
    @State private var isGeneratingPDF = false
    @State private var isGeneratingCSV = false
    @State private var isGeneratingManifest = false
    @State private var generatedPDFURL: URL?
    @State private var generatedCSVURL: URL?
    @State private var generatedManifestURL: URL?
    @State private var showingShareSheet = false
    @State private var shareURL: URL?

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AnalyticsDashboardView()
                } label: {
                    Label("Analytics Dashboard", systemImage: "chart.bar.xaxis")
                }
            }

            Section("Export") {
                Button(action: generateInsuranceReport) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Insurance Report (PDF)")
                            Text("Full inventory with photos, values, and totals")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        if isGeneratingPDF {
                            ProgressView()
                        } else {
                            Image(systemName: "doc.richtext")
                        }
                    }
                }
                .disabled(isGeneratingPDF || bins.isEmpty)

                Button(action: generateCSV) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export CSV")
                            Text("Spreadsheet-friendly data for all items")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        if isGeneratingCSV {
                            ProgressView()
                        } else {
                            Image(systemName: "tablecells")
                        }
                    }
                }
                .disabled(isGeneratingCSV || bins.isEmpty)
            }

            Section("Bin Manifest") {
                Picker("Select Bin", selection: $selectedBin) {
                    Text("Choose a bin...").tag(nil as Bin?)
                    ForEach(bins) { bin in
                        Text(bin.displayName).tag(bin as Bin?)
                    }
                }

                Button(action: generateManifest) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Print Manifest (PDF)")
                            Text("Itemized contents list for a single bin")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        if isGeneratingManifest {
                            ProgressView()
                        } else {
                            Image(systemName: "list.clipboard")
                        }
                    }
                }
                .disabled(selectedBin == nil || isGeneratingManifest)
            }
        }
        .navigationTitle("Reports")
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func generateInsuranceReport() {
        isGeneratingPDF = true
        Task.detached {
            let data = ReportService.generateInsuranceReport(zones: zones, bins: bins)
            await MainActor.run {
                isGeneratingPDF = false
                guard let data else { return }
                let url = saveTempFile(data: data, name: "binthere-inventory-report.pdf")
                shareURL = url
                showingShareSheet = true
            }
        }
    }

    private func generateCSV() {
        isGeneratingCSV = true
        Task.detached {
            let data = ReportService.generateCSV(zones: zones, bins: bins)
            await MainActor.run {
                isGeneratingCSV = false
                guard let data else { return }
                let url = saveTempFile(data: data, name: "binthere-inventory.csv")
                shareURL = url
                showingShareSheet = true
            }
        }
    }

    private func generateManifest() {
        guard let bin = selectedBin else { return }
        isGeneratingManifest = true
        Task.detached {
            let data = ReportService.generateBinManifest(bin: bin)
            await MainActor.run {
                isGeneratingManifest = false
                guard let data else { return }
                let url = saveTempFile(data: data, name: "bin-\(bin.code)-manifest.pdf")
                shareURL = url
                showingShareSheet = true
            }
        }
    }

    private func saveTempFile(data: Data, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url)
            return url
        } catch {
            print("Failed to save report: \(error)")
            return nil
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
