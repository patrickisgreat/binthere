import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                BinListView()
            }
            .tabItem {
                Label("Bins", systemImage: "archivebox")
            }
            .tag(0)
            .accessibilityIdentifier("binsTab")

            NavigationStack {
                ZonesGridView()
            }
            .tabItem {
                Label("Zones", systemImage: "square.grid.2x2")
            }
            .tag(1)
            .accessibilityIdentifier("zonesTab")

            NavigationStack {
                CheckedOutView()
                    .navigationDestination(for: Item.self) { item in
                        ItemDetailView(item: item)
                    }
            }
            .tabItem {
                Label("Out", systemImage: "arrow.up.forward.circle")
            }
            .tag(2)
            .accessibilityIdentifier("checkedOutTab")

            NavigationStack {
                ScannerTab()
            }
            .tabItem {
                Label("Scan", systemImage: "qrcode.viewfinder")
            }
            .tag(3)
            .accessibilityIdentifier("scanTab")

            NavigationStack {
                ReportsView()
            }
            .tabItem {
                Label("Reports", systemImage: "chart.bar")
            }
            .tag(4)
            .accessibilityIdentifier("reportsTab")

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(5)
            .accessibilityIdentifier("settingsTab")
        }
    }
}
