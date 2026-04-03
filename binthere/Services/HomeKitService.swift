import HomeKit

@Observable
final class HomeKitService: NSObject, HMHomeManagerDelegate {
    var rooms: [String] = []
    var isLoading = false
    var error: String?

    private var homeManager: HMHomeManager?
    private var continuation: CheckedContinuation<Void, Never>?

    func fetchRooms() async {
        isLoading = true
        error = nil
        rooms = []

        homeManager = HMHomeManager()
        homeManager?.delegate = self

        // Wait for HomeKit to deliver homes
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }

        isLoading = false
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        let allRooms = manager.homes
            .flatMap(\.rooms)
            .map(\.name)

        // Deduplicate and sort
        rooms = Array(Set(allRooms)).sorted()

        if rooms.isEmpty && manager.homes.isEmpty {
            error = "No homes configured in HomeKit. Set up a home in the Home app first."
        }

        continuation?.resume()
        continuation = nil
    }
}
