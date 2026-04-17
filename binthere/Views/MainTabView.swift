import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(0)
            .accessibilityIdentifier("searchTab")

            NavigationStack {
                BinListView()
            }
            .tabItem {
                Label("Bins", systemImage: "archivebox")
            }
            .tag(1)
            .accessibilityIdentifier("binsTab")

            NavigationStack {
                ZonesGridView()
            }
            .tabItem {
                Label("Zones", systemImage: "square.grid.2x2")
            }
            .tag(2)
            .accessibilityIdentifier("zonesTab")

            NavigationStack {
                ScannerTab()
            }
            .tabItem {
                Label("Scan", systemImage: "qrcode.viewfinder")
            }
            .tag(3)
            .accessibilityIdentifier("scanTab")

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(4)
            .accessibilityIdentifier("settingsTab")
        }
    }
}
