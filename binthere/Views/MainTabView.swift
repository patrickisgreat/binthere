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
