import SwiftUI
import SwiftData

@main
struct binthereApp: App { // swiftlint:disable:this type_name
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Zone.self,
            Bin.self,
            Item.self,
            CheckoutRecord.self,
            CustomAttribute.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AuthGateView()
        }
        .modelContainer(sharedModelContainer)
    }
}
