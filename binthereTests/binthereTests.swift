import XCTest
import SwiftData
@testable import binthere

final class ModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Zone.self, Bin.self, Item.self, CheckoutRecord.self,
            configurations: config
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Zone Tests

    func test_zoneCreation_setsNameAndDescription() {
        let zone = Zone(name: "Garage", locationDescription: "Detached garage")
        context.insert(zone)

        XCTAssertEqual(zone.name, "Garage")
        XCTAssertEqual(zone.locationDescription, "Detached garage")
        XCTAssertTrue(zone.bins.isEmpty)
    }

    func test_zoneDelete_nullifiesBinZone() throws {
        let zone = Zone(name: "Attic")
        let bin = Bin(name: "Box A")
        bin.zone = zone
        context.insert(zone)
        context.insert(bin)
        try context.save()

        XCTAssertEqual(bin.zone?.name, "Attic")

        context.delete(zone)
        try context.save()

        XCTAssertNil(bin.zone)
    }

    // MARK: - Bin Tests

    func test_binCreation_setsDefaults() {
        let bin = Bin(name: "Shelf 1", binDescription: "Top shelf", location: "Office")
        context.insert(bin)

        XCTAssertEqual(bin.name, "Shelf 1")
        XCTAssertEqual(bin.binDescription, "Top shelf")
        XCTAssertEqual(bin.location, "Office")
        XCTAssertTrue(bin.items.isEmpty)
        XCTAssertNil(bin.zone)
        XCTAssertNotNil(bin.id)
    }

    func test_binDelete_cascadesItems() throws {
        let bin = Bin(name: "Bin 1")
        let item = Item(name: "Hammer", bin: bin)
        context.insert(bin)
        context.insert(item)
        try context.save()

        XCTAssertEqual(bin.items.count, 1)

        context.delete(bin)
        try context.save()

        let descriptor = FetchDescriptor<Item>()
        let remainingItems = try context.fetch(descriptor)
        XCTAssertTrue(remainingItems.isEmpty)
    }

    // MARK: - Item Tests

    func test_itemCreation_setsDefaults() {
        let bin = Bin(name: "Drawer")
        let item = Item(name: "Screwdriver", itemDescription: "Phillips head", bin: bin)
        context.insert(bin)
        context.insert(item)

        XCTAssertEqual(item.name, "Screwdriver")
        XCTAssertEqual(item.itemDescription, "Phillips head")
        XCTAssertEqual(item.bin?.name, "Drawer")
        XCTAssertFalse(item.isCheckedOut)
        XCTAssertTrue(item.tags.isEmpty)
        XCTAssertTrue(item.customFields.isEmpty)
        XCTAssertTrue(item.imagePaths.isEmpty)
        XCTAssertTrue(item.checkoutHistory.isEmpty)
    }

    func test_itemTags_persistCorrectly() throws {
        let item = Item(name: "Tape")
        item.tags = ["tools", "adhesive", "office"]
        context.insert(item)
        try context.save()

        XCTAssertEqual(item.tags.count, 3)
        XCTAssertTrue(item.tags.contains("tools"))
    }

    func test_itemCustomFields_persistCorrectly() throws {
        let item = Item(name: "Vintage Watch")
        item.customFields = ["brand": "Seiko", "year": "1985", "condition": "Good"]
        context.insert(item)
        try context.save()

        XCTAssertEqual(item.customFields["brand"], "Seiko")
        XCTAssertEqual(item.customFields.count, 3)
    }

    func test_itemMoveBetweenBins() throws {
        let bin1 = Bin(name: "Bin A")
        let bin2 = Bin(name: "Bin B")
        let item = Item(name: "Wrench", bin: bin1)
        context.insert(bin1)
        context.insert(bin2)
        context.insert(item)
        try context.save()

        XCTAssertEqual(bin1.items.count, 1)
        XCTAssertEqual(bin2.items.count, 0)

        item.bin = bin2
        try context.save()

        XCTAssertEqual(item.bin?.name, "Bin B")
    }

    // MARK: - CheckoutRecord Tests

    func test_checkoutRecord_isActiveWhenNotCheckedIn() {
        let item = Item(name: "Drill")
        let record = CheckoutRecord(item: item, checkedOutTo: "Alice")
        context.insert(item)
        context.insert(record)

        XCTAssertTrue(record.isActive)
        XCTAssertNil(record.checkedInAt)
        XCTAssertEqual(record.checkedOutTo, "Alice")
    }

    func test_checkoutRecord_isNotActiveAfterCheckIn() {
        let item = Item(name: "Saw")
        let record = CheckoutRecord(item: item, checkedOutTo: "Bob")
        context.insert(item)
        context.insert(record)

        record.checkedInAt = Date()

        XCTAssertFalse(record.isActive)
    }

    func test_checkoutFlow_updatesItemStatus() throws {
        let item = Item(name: "Level")
        context.insert(item)
        XCTAssertFalse(item.isCheckedOut)

        // Check out
        let record = CheckoutRecord(item: item, checkedOutTo: "Charlie")
        context.insert(record)
        item.isCheckedOut = true
        try context.save()

        XCTAssertTrue(item.isCheckedOut)
        XCTAssertTrue(record.isActive)

        // Check in
        record.checkedInAt = Date()
        item.isCheckedOut = false
        try context.save()

        XCTAssertFalse(item.isCheckedOut)
        XCTAssertFalse(record.isActive)
    }

    func test_checkoutRecord_withExpectedReturnDate() throws {
        let item = Item(name: "Drill Press")
        let returnDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 7, to: Date()))
        let record = CheckoutRecord(
            item: item,
            checkedOutTo: "Dave",
            expectedReturnDate: returnDate,
            notes: "For weekend project"
        )
        context.insert(item)
        context.insert(record)

        XCTAssertNotNil(record.expectedReturnDate)
        XCTAssertEqual(record.notes, "For weekend project")
    }

    func test_itemDelete_cascadesCheckoutRecords() throws {
        let item = Item(name: "Sander")
        let record = CheckoutRecord(item: item, checkedOutTo: "Eve")
        context.insert(item)
        context.insert(record)
        try context.save()

        context.delete(item)
        try context.save()

        let descriptor = FetchDescriptor<CheckoutRecord>()
        let remainingRecords = try context.fetch(descriptor)
        XCTAssertTrue(remainingRecords.isEmpty)
    }
}

final class QRGeneratorServiceTests: XCTestCase {

    func test_generateQRCode_returnsImage() {
        let uuid = UUID().uuidString
        let image = QRGeneratorService.generateQRCode(from: uuid)
        XCTAssertNotNil(image)
    }

    func test_generateQRCode_producesNonZeroSizeImage() throws {
        let image = try XCTUnwrap(QRGeneratorService.generateQRCode(from: "test-data"))
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }
}

final class ImageStorageServiceTests: XCTestCase {

    func test_saveAndLoadImage_roundTrip() {
        let testImage = createTestImage()
        guard let filename = ImageStorageService.saveImage(testImage) else {
            XCTFail("Failed to save image")
            return
        }

        let loaded = ImageStorageService.loadImage(filename: filename)
        XCTAssertNotNil(loaded)

        // Cleanup
        ImageStorageService.deleteImage(filename: filename)
    }

    func test_deleteImage_removesFile() {
        let testImage = createTestImage()
        guard let filename = ImageStorageService.saveImage(testImage) else {
            XCTFail("Failed to save image")
            return
        }

        ImageStorageService.deleteImage(filename: filename)

        let loaded = ImageStorageService.loadImage(filename: filename)
        XCTAssertNil(loaded)
    }

    func test_loadImage_returnsNilForMissingFile() {
        let loaded = ImageStorageService.loadImage(filename: "nonexistent.jpg")
        XCTAssertNil(loaded)
    }

    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
