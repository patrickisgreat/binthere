import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                BinListView()
            }
            .tabItem {
                Label("Bins", systemImage: "archivebox")
            }

            NavigationStack {
                ZonesGridView()
            }
            .tabItem {
                Label("Zones", systemImage: "square.grid.2x2")
            }

            NavigationStack {
                ScannerTab()
            }
            .tabItem {
                Label("Scan", systemImage: "qrcode.viewfinder")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}
