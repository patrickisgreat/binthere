import XCTest
import SwiftData
@testable import binthere

@MainActor
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
        XCTAssertTrue(zone.color.isEmpty)
        XCTAssertTrue(zone.icon.isEmpty)
    }

    func test_zoneCreation_withColorAndIcon() throws {
        let zone = Zone(name: "Office", color: "blue", icon: "desktopcomputer")
        context.insert(zone)
        try context.save()

        XCTAssertEqual(zone.color, "blue")
        XCTAssertEqual(zone.icon, "desktopcomputer")
    }

    func test_zoneTotalItemCount() throws {
        let zone = Zone(name: "Garage")
        let bin1 = Bin(code: "G001")
        let bin2 = Bin(code: "G002")
        bin1.zone = zone
        bin2.zone = zone
        let item1 = Item(name: "Hammer", bin: bin1)
        let item2 = Item(name: "Wrench", bin: bin1)
        let item3 = Item(name: "Drill", bin: bin2)
        context.insert(zone)
        context.insert(bin1)
        context.insert(bin2)
        context.insert(item1)
        context.insert(item2)
        context.insert(item3)
        try context.save()

        XCTAssertEqual(zone.totalItemCount, 3)
        XCTAssertEqual(zone.bins.count, 2)
    }

    func test_zoneDelete_nullifiesBinZone() throws {
        let zone = Zone(name: "Attic")
        let bin = Bin(code: "A1B2")
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

    func test_binCreation_setsCodeAndDefaults() {
        let bin = Bin(code: "D4J6", name: "Shelf 1", binDescription: "Top shelf", location: "Office")
        context.insert(bin)

        XCTAssertEqual(bin.code, "D4J6")
        XCTAssertEqual(bin.name, "Shelf 1")
        XCTAssertEqual(bin.binDescription, "Top shelf")
        XCTAssertEqual(bin.location, "Office")
        XCTAssertTrue(bin.items.isEmpty)
        XCTAssertNil(bin.zone)
        XCTAssertNotNil(bin.id)
        XCTAssertTrue(bin.color.isEmpty)
        XCTAssertNil(bin.qrCodeImagePath)
        XCTAssertTrue(bin.contentImagePaths.isEmpty)
    }

    func test_binCreation_withoutName() {
        let bin = Bin(code: "X7K3")
        context.insert(bin)

        XCTAssertEqual(bin.code, "X7K3")
        XCTAssertTrue(bin.name.isEmpty)
        XCTAssertEqual(bin.displayName, "X7K3")
    }

    func test_binDisplayName_withLabel() {
        let bin = Bin(code: "D4J6", name: "Garage Shelf")
        XCTAssertEqual(bin.displayName, "D4J6 — Garage Shelf")
    }

    func test_binDisplayName_withoutLabel() {
        let bin = Bin(code: "D4J6")
        XCTAssertEqual(bin.displayName, "D4J6")
    }

    func test_binColor_persists() throws {
        let bin = Bin(code: "C1C1")
        bin.color = "blue"
        context.insert(bin)
        try context.save()

        XCTAssertEqual(bin.color, "blue")
    }

    func test_binQRCodeStorage() throws {
        let bin = Bin(code: "QR01")
        context.insert(bin)

        guard let qrImage = QRGeneratorService.generateQRCode(from: bin.id.uuidString),
              let qrPath = ImageStorageService.saveImage(qrImage) else {
            XCTFail("Failed to generate/save QR code")
            return
        }

        bin.qrCodeImagePath = qrPath
        try context.save()

        XCTAssertNotNil(bin.qrCodeImagePath)
        XCTAssertNotNil(ImageStorageService.loadImage(filename: qrPath))

        ImageStorageService.deleteImage(filename: qrPath)
    }

    func test_binContentImagePaths() throws {
        let bin = Bin(code: "PH01")
        context.insert(bin)

        bin.contentImagePaths = ["photo1.jpg", "photo2.jpg"]
        try context.save()

        XCTAssertEqual(bin.contentImagePaths.count, 2)
        XCTAssertTrue(bin.contentImagePaths.contains("photo1.jpg"))
    }

    func test_binDelete_cascadesItems() throws {
        let bin = Bin(code: "B1N1")
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
        let bin = Bin(code: "DR01")
        let item = Item(name: "Screwdriver", itemDescription: "Phillips head", bin: bin)
        context.insert(bin)
        context.insert(item)

        XCTAssertEqual(item.name, "Screwdriver")
        XCTAssertEqual(item.itemDescription, "Phillips head")
        XCTAssertEqual(item.bin?.code, "DR01")
        XCTAssertFalse(item.isCheckedOut)
        XCTAssertTrue(item.tags.isEmpty)
        XCTAssertTrue(item.customFields.isEmpty)
        XCTAssertTrue(item.imagePaths.isEmpty)
        XCTAssertTrue(item.checkoutHistory.isEmpty)
        XCTAssertTrue(item.color.isEmpty)
    }

    func test_itemColor_persists() throws {
        let item = Item(name: "Tape")
        item.color = "red"
        context.insert(item)
        try context.save()

        XCTAssertEqual(item.color, "red")
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
        let bin1 = Bin(code: "AA11")
        let bin2 = Bin(code: "BB22")
        let item = Item(name: "Wrench", bin: bin1)
        context.insert(bin1)
        context.insert(bin2)
        context.insert(item)
        try context.save()

        XCTAssertEqual(bin1.items.count, 1)
        XCTAssertEqual(bin2.items.count, 0)

        item.bin = bin2
        try context.save()

        XCTAssertEqual(item.bin?.code, "BB22")
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

        let record = CheckoutRecord(item: item, checkedOutTo: "Charlie")
        context.insert(record)
        item.isCheckedOut = true
        try context.save()

        XCTAssertTrue(item.isCheckedOut)
        XCTAssertTrue(record.isActive)

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

// MARK: - Item Enrichment Tests

@MainActor
final class ItemEnrichmentTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Zone.self, Bin.self, Item.self, CheckoutRecord.self, CustomAttribute.self,
            configurations: config
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func test_itemValue_defaultsNil() {
        let item = Item(name: "Drill")
        context.insert(item)
        XCTAssertNil(item.value)
        XCTAssertTrue(item.valueSource.isEmpty)
        XCTAssertNil(item.valueUpdatedAt)
    }

    func test_itemValueTracking() throws {
        let item = Item(name: "Drill")
        context.insert(item)
        item.value = 150.00
        item.valueSource = "manual"
        item.valueUpdatedAt = Date()
        try context.save()

        XCTAssertEqual(item.value, 150.00)
        XCTAssertEqual(item.valueSource, "manual")
        XCTAssertNotNil(item.valueUpdatedAt)
    }

    func test_binTotalValue_rollup() throws {
        let bin = Bin(code: "V001")
        let item1 = Item(name: "Item 1", bin: bin)
        let item2 = Item(name: "Item 2", bin: bin)
        let item3 = Item(name: "Item 3", bin: bin)
        item1.value = 50.00
        item2.value = 100.00
        // item3 has no value
        context.insert(bin)
        context.insert(item1)
        context.insert(item2)
        context.insert(item3)
        try context.save()

        XCTAssertEqual(bin.totalValue, 150.00)
        XCTAssertEqual(bin.itemsWithValueCount, 2)
    }

    func test_zoneTotalValue_rollup() throws {
        let zone = Zone(name: "Garage")
        let bin1 = Bin(code: "G001")
        let bin2 = Bin(code: "G002")
        bin1.zone = zone
        bin2.zone = zone
        let item1 = Item(name: "Tool", bin: bin1)
        let item2 = Item(name: "Gadget", bin: bin2)
        item1.value = 25.00
        item2.value = 75.00
        context.insert(zone)
        context.insert(bin1)
        context.insert(bin2)
        context.insert(item1)
        context.insert(item2)
        try context.save()

        XCTAssertEqual(zone.totalValue, 100.00)
    }

    func test_customAttribute_persists() throws {
        let item = Item(name: "Watch")
        context.insert(item)

        let brand = CustomAttribute(name: "Brand", type: .text)
        brand.textValue = "Seiko"
        brand.item = item
        context.insert(brand)

        let year = CustomAttribute(name: "Year", type: .number)
        year.numberValue = 1985
        year.item = item
        context.insert(year)
        try context.save()

        XCTAssertEqual(item.customAttributes.count, 2)
    }

    func test_customAttribute_cascadeDelete() throws {
        let item = Item(name: "Watch")
        let attribute = CustomAttribute(name: "Brand", type: .text)
        attribute.textValue = "Seiko"
        attribute.item = item
        context.insert(item)
        context.insert(attribute)
        try context.save()

        context.delete(item)
        try context.save()

        let descriptor = FetchDescriptor<CustomAttribute>()
        let remaining = try context.fetch(descriptor)
        XCTAssertTrue(remaining.isEmpty)
    }

    func test_customAttribute_displayValue_byType() {
        let textAttr = CustomAttribute(name: "Brand", type: .text)
        textAttr.textValue = "Seiko"
        XCTAssertEqual(textAttr.displayValue, "Seiko")

        let boolAttr = CustomAttribute(name: "Waterproof", type: .boolean)
        boolAttr.boolValue = true
        XCTAssertEqual(boolAttr.displayValue, "Yes")

        boolAttr.boolValue = false
        XCTAssertEqual(boolAttr.displayValue, "No")

        let dateAttr = CustomAttribute(name: "Purchased", type: .date)
        dateAttr.dateValue = nil
        XCTAssertEqual(dateAttr.displayValue, "—")
    }

    func test_itemNotes_persist() throws {
        let item = Item(name: "Box")
        context.insert(item)
        item.notes = "Contains grandma's china. Handle with care."
        try context.save()

        XCTAssertEqual(item.notes, "Contains grandma's china. Handle with care.")
    }
}

// MARK: - CurrencyFormatter Tests

final class CurrencyFormatterTests: XCTestCase {

    func test_format_nilReturnsDash() {
        XCTAssertEqual(CurrencyFormatter.format(nil), "—")
    }

    func test_format_zeroReturnsDash() {
        XCTAssertEqual(CurrencyFormatter.format(0), "—")
    }

    func test_format_positiveValue() {
        let result = CurrencyFormatter.format(123.45)
        XCTAssertFalse(result.isEmpty)
        XCTAssertNotEqual(result, "—")
    }

    func test_parse_currencyString() {
        XCTAssertEqual(CurrencyFormatter.parse("$123.45"), 123.45)
        XCTAssertEqual(CurrencyFormatter.parse("1000"), 1000)
        XCTAssertEqual(CurrencyFormatter.parse("49.99"), 49.99)
    }
}

// MARK: - ReportService Tests

@MainActor
final class ReportServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Zone.self, Bin.self, Item.self, CheckoutRecord.self, CustomAttribute.self,
            configurations: config
        )
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func test_generateCSV_producesValidOutput() throws {
        let zone = Zone(name: "Garage")
        let bin = Bin(code: "G001", name: "Shelf")
        bin.zone = zone
        let item = Item(name: "Hammer", itemDescription: "Ball peen", bin: bin)
        item.value = 25.00
        item.tags = ["tools"]
        context.insert(zone)
        context.insert(bin)
        context.insert(item)
        try context.save()

        guard let data = ReportService.generateCSV(zones: [zone], bins: [bin]),
              let csv = String(data: data, encoding: .utf8) else {
            XCTFail("Failed to generate CSV")
            return
        }

        XCTAssertTrue(csv.contains("Zone,Bin Code,Bin Label"))
        XCTAssertTrue(csv.contains("Garage"))
        XCTAssertTrue(csv.contains("G001"))
        XCTAssertTrue(csv.contains("Hammer"))
        XCTAssertTrue(csv.contains("25.00"))
    }

    func test_generateCSV_escapesCommasInFields() throws {
        let bin = Bin(code: "T001")
        let item = Item(name: "Drill, cordless", bin: bin)
        context.insert(bin)
        context.insert(item)
        try context.save()

        guard let data = ReportService.generateCSV(zones: [], bins: [bin]),
              let csv = String(data: data, encoding: .utf8) else {
            XCTFail("Failed to generate CSV")
            return
        }

        XCTAssertTrue(csv.contains("\"Drill, cordless\""))
    }

    func test_generateInsuranceReport_returnsData() throws {
        let bin = Bin(code: "R001")
        let item = Item(name: "Wrench", bin: bin)
        item.value = 15.00
        context.insert(bin)
        context.insert(item)
        try context.save()

        let data = ReportService.generateInsuranceReport(zones: [], bins: [bin])
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
    }

    func test_generateBinManifest_returnsData() throws {
        let bin = Bin(code: "M001")
        let item = Item(name: "Tape", bin: bin)
        context.insert(bin)
        context.insert(item)
        try context.save()

        let data = ReportService.generateBinManifest(bin: bin)
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
    }
}

// MARK: - CodeGenerator Tests

final class CodeGeneratorTests: XCTestCase {

    func test_generateCode_returns4Characters() {
        let code = CodeGenerator.generateCode()
        XCTAssertEqual(code.count, 4)
    }

    func test_generateCode_usesOnlyAllowedCharacters() {
        let allowedChars = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for _ in 0..<50 {
            let code = CodeGenerator.generateCode()
            for char in code {
                XCTAssertTrue(allowedChars.contains(char), "Code '\(code)' contains disallowed character '\(char)'")
            }
        }
    }

    func test_generateCode_excludesAmbiguousCharacters() {
        let ambiguous = Set("IO01")
        for _ in 0..<100 {
            let code = CodeGenerator.generateCode()
            for char in code {
                XCTAssertFalse(ambiguous.contains(char), "Code '\(code)' contains ambiguous character '\(char)'")
            }
        }
    }

    func test_generateCode_avoidsCollisions() {
        let existing: Set<String> = ["AAAA", "BBBB", "CCCC"]
        for _ in 0..<50 {
            let code = CodeGenerator.generateCode(existingCodes: existing)
            XCTAssertFalse(existing.contains(code))
        }
    }

    func test_generateCode_producesUniqueResults() {
        var codes = Set<String>()
        for _ in 0..<100 {
            codes.insert(CodeGenerator.generateCode(existingCodes: codes))
        }
        XCTAssertEqual(codes.count, 100)
    }
}

// MARK: - QR Generator Tests

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

    func test_generateQRLabel_returnsImage() {
        let label = QRGeneratorService.generateQRLabel(code: "D4J6", binID: UUID().uuidString)
        XCTAssertNotNil(label)
    }

    func test_generateQRLabel_isLargerThanRawQR() throws {
        let rawQR = try XCTUnwrap(QRGeneratorService.generateQRCode(from: "test"))
        let label = try XCTUnwrap(QRGeneratorService.generateQRLabel(code: "TEST", binID: "test"))
        XCTAssertGreaterThan(label.size.height, rawQR.size.height)
    }
}

// MARK: - Image Storage Tests

final class ImageStorageServiceTests: XCTestCase {

    func test_saveAndLoadImage_roundTrip() {
        let testImage = createTestImage()
        guard let filename = ImageStorageService.saveImage(testImage) else {
            XCTFail("Failed to save image")
            return
        }

        let loaded = ImageStorageService.loadImage(filename: filename)
        XCTAssertNotNil(loaded)

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
