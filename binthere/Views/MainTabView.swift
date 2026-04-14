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
                ScannerTab()
            }
            .tabItem {
                Label("Scan", systemImage: "qrcode.viewfinder")
            }
            .tag(2)
            .accessibilityIdentifier("scanTab")

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
            .accessibilityIdentifier("settingsTab")
        }
    }
}
