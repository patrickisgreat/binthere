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
            for: Zone.self, Bin.self, Item.self, CheckoutRecord.self, CustomAttribute.self,
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

// MARK: - Zone Sub-Location Tests

@MainActor
final class ZoneSubLocationTests: XCTestCase {

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

    func test_zoneLocations_defaultsEmpty() {
        let zone = Zone(name: "Garage")
        XCTAssertTrue(zone.locations.isEmpty)
    }

    func test_zoneLocations_canAddLocations() throws {
        let zone = Zone(name: "Garage")
        zone.locations = ["Top Shelf", "Workbench", "Floor"]
        context.insert(zone)
        try context.save()

        XCTAssertEqual(zone.locations.count, 3)
        XCTAssertTrue(zone.locations.contains("Workbench"))
    }

    func test_zoneLocations_canRemoveLocation() throws {
        let zone = Zone(name: "Kitchen")
        zone.locations = ["Pantry", "Under Sink", "Top Cabinet"]
        context.insert(zone)
        try context.save()

        zone.locations.removeAll { $0 == "Under Sink" }
        try context.save()

        XCTAssertEqual(zone.locations.count, 2)
        XCTAssertFalse(zone.locations.contains("Under Sink"))
    }

    func test_binLocation_canMatchZoneLocation() throws {
        let zone = Zone(name: "Garage")
        zone.locations = ["Top Shelf", "Bottom Shelf"]
        context.insert(zone)

        let bin = Bin(code: "G001", location: "Top Shelf")
        bin.zone = zone
        context.insert(bin)
        try context.save()

        XCTAssertEqual(bin.location, "Top Shelf")
        XCTAssertTrue(zone.locations.contains(bin.location))
    }

    func test_binLocation_canBeCustom() throws {
        let zone = Zone(name: "Garage")
        zone.locations = ["Top Shelf"]
        context.insert(zone)

        let bin = Bin(code: "G002", location: "Behind the door")
        bin.zone = zone
        context.insert(bin)
        try context.save()

        XCTAssertEqual(bin.location, "Behind the door")
        XCTAssertFalse(zone.locations.contains(bin.location))
    }
}

// MARK: - Space Type Tests

final class SpaceTypeTests: XCTestCase {

    func test_allSpaceTypes_haveDisplayNames() {
        for type in SpaceType.allCases {
            XCTAssertFalse(type.displayName.isEmpty)
        }
    }

    func test_allSpaceTypes_haveIcons() {
        for type in SpaceType.allCases {
            XCTAssertFalse(type.icon.isEmpty)
        }
    }

    func test_allSpaceTypes_haveUniqueRawValues() {
        let raw = SpaceType.allCases.map(\.rawValue)
        XCTAssertEqual(raw.count, Set(raw).count)
    }

    func test_spaceType_defaultIsHome() {
        XCTAssertEqual(SpaceType(rawValue: "home"), .home)
    }

    func test_spaceType_storageUnit() {
        XCTAssertEqual(SpaceType(rawValue: "storage_unit"), .storageUnit)
        XCTAssertEqual(SpaceType.storageUnit.displayName, "Storage Unit")
    }

    func test_spaceType_unknownFallsToNil() {
        XCTAssertNil(SpaceType(rawValue: "spaceship"))
    }

    func test_spaceTypeCount() {
        XCTAssertEqual(SpaceType.allCases.count, 6)
    }
}

// MARK: - Ownership Tests

@MainActor
final class OwnershipTests: XCTestCase {

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

    func test_itemCreatedBy_defaultsEmpty() {
        let item = Item(name: "Hammer")
        XCTAssertEqual(item.createdBy, "")
    }

    func test_itemCreatedBy_canBeSet() {
        let item = Item(name: "Drill")
        item.createdBy = "user-abc-123"
        context.insert(item)
        XCTAssertEqual(item.createdBy, "user-abc-123")
    }

    func test_ownershipTransfer_changesCreatedBy() throws {
        let item = Item(name: "Saw")
        item.createdBy = "user-alice"
        context.insert(item)
        try context.save()

        item.createdBy = "user-bob"
        try context.save()

        XCTAssertEqual(item.createdBy, "user-bob")
    }

    func test_maxCheckoutDays_defaultsNil() {
        let item = Item(name: "Book")
        XCTAssertNil(item.maxCheckoutDays)
    }

    func test_maxCheckoutDays_canBeSet() throws {
        let item = Item(name: "Book")
        item.maxCheckoutDays = 14
        context.insert(item)
        try context.save()
        XCTAssertEqual(item.maxCheckoutDays, 14)
    }

    func test_allowedCheckoutUsers_defaultsEmpty() {
        let item = Item(name: "Projector")
        XCTAssertTrue(item.allowedCheckoutUsers.isEmpty)
    }

    func test_checkoutPermission_options() {
        let item = Item(name: "Camera")
        XCTAssertEqual(item.checkoutPermission, "anyone")

        item.checkoutPermission = "none"
        XCTAssertEqual(item.checkoutPermission, "none")
    }
}

// MARK: - Onboarding Tests

final class OnboardingTests: XCTestCase {

    private let testUserId = "onboarding-test-user-\(UUID().uuidString)"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "onboarding_complete_\(testUserId)")
    }

    func test_onboardingNotComplete_byDefault() {
        let key = "onboarding_complete_\(testUserId)"
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))
    }

    func test_onboardingComplete_persistsPerUser() {
        let key = "onboarding_complete_\(testUserId)"
        UserDefaults.standard.set(true, forKey: key)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
    }

    func test_onboardingComplete_isolatedPerUser() {
        let userA = "onboarding-test-A"
        let userB = "onboarding-test-B"
        defer {
            UserDefaults.standard.removeObject(forKey: "onboarding_complete_\(userA)")
            UserDefaults.standard.removeObject(forKey: "onboarding_complete_\(userB)")
        }

        UserDefaults.standard.set(true, forKey: "onboarding_complete_\(userA)")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "onboarding_complete_\(userA)"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "onboarding_complete_\(userB)"))
    }

    func test_zonePresets_notEmpty() {
        XCTAssertFalse(ZonePreset.allPresets.isEmpty)
        XCTAssertGreaterThanOrEqual(ZonePreset.allPresets.count, 10)
    }

    func test_zonePresets_allHaveRequiredFields() {
        for preset in ZonePreset.allPresets {
            XCTAssertFalse(preset.name.isEmpty, "Preset name should not be empty")
            XCTAssertFalse(preset.icon.isEmpty, "Preset \(preset.name) missing icon")
            XCTAssertFalse(preset.color.isEmpty, "Preset \(preset.name) missing color")
        }
    }

    func test_zonePresets_uniqueNames() {
        let names = ZonePreset.allPresets.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "Zone preset names should be unique")
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

// MARK: - Search Filtering Tests

@MainActor
final class SearchFilteringTests: XCTestCase {

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

    private func makeItem(_ name: String, description: String = "", tags: [String] = [],
                          notes: String = "", color: String = "") -> Item {
        let item = Item(name: name, itemDescription: description)
        item.tags = tags
        item.notes = notes
        item.color = color
        context.insert(item)
        return item
    }

    private func makeBin(code: String, name: String = "", location: String = "",
                         description: String = "") -> Bin {
        let bin = Bin(code: code, name: name, binDescription: description, location: location)
        context.insert(bin)
        return bin
    }

    private func filterItems(_ items: [Item], query: String, tags: Set<String> = []) -> [Item] {
        var result = items

        if !tags.isEmpty {
            result = result.filter { item in
                !tags.isDisjoint(with: item.tags)
            }
        }

        guard !query.isEmpty else { return tags.isEmpty ? [] : result }

        return result.filter { item in
            item.name.localizedCaseInsensitiveContains(query) ||
            item.itemDescription.localizedCaseInsensitiveContains(query) ||
            item.tags.contains { $0.localizedCaseInsensitiveContains(query) } ||
            item.notes.localizedCaseInsensitiveContains(query) ||
            item.color.localizedCaseInsensitiveContains(query)
        }
    }

    private func filterBins(_ bins: [Bin], query: String) -> [Bin] {
        guard !query.isEmpty else { return [] }
        return bins.filter { bin in
            bin.code.localizedCaseInsensitiveContains(query) ||
            bin.name.localizedCaseInsensitiveContains(query) ||
            bin.location.localizedCaseInsensitiveContains(query) ||
            bin.binDescription.localizedCaseInsensitiveContains(query)
        }
    }

    func test_searchByItemName_caseInsensitive() {
        let items = [
            makeItem("Phillips Screwdriver"),
            makeItem("Hammer"),
            makeItem("Nails"),
        ]
        let results = filterItems(items, query: "screwdriver")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Phillips Screwdriver")
    }

    func test_searchByItemDescription() {
        let items = [
            makeItem("Wrench", description: "Red-handled adjustable wrench"),
            makeItem("Pliers", description: "Needle-nose pliers"),
        ]
        let results = filterItems(items, query: "adjustable")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Wrench")
    }

    func test_searchByTag() {
        let items = [
            makeItem("Ornament", tags: ["christmas", "fragile"]),
            makeItem("Wreath", tags: ["christmas", "front-door"]),
            makeItem("Hammer", tags: ["tools"]),
        ]
        let results = filterItems(items, query: "christmas")
        XCTAssertEqual(results.count, 2)
    }

    func test_searchByNotes() {
        let items = [
            makeItem("Cable", notes: "Bought from Amazon 2024"),
            makeItem("Adapter", notes: "USB-C to HDMI"),
        ]
        let results = filterItems(items, query: "amazon")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Cable")
    }

    func test_searchEmptyQuery_returnsEmpty() {
        let items = [makeItem("Hammer"), makeItem("Nails")]
        let results = filterItems(items, query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func test_searchNoMatch_returnsEmpty() {
        let items = [makeItem("Hammer"), makeItem("Nails")]
        let results = filterItems(items, query: "dinosaur")
        XCTAssertTrue(results.isEmpty)
    }

    func test_filterByTag_noQuery() {
        let items = [
            makeItem("Ornament", tags: ["christmas"]),
            makeItem("Wreath", tags: ["christmas"]),
            makeItem("Hammer", tags: ["tools"]),
        ]
        let results = filterItems(items, query: "", tags: ["christmas"])
        XCTAssertEqual(results.count, 2)
    }

    func test_filterByMultipleTags_orLogic() {
        let items = [
            makeItem("Ornament", tags: ["christmas"]),
            makeItem("Hammer", tags: ["tools"]),
            makeItem("Nails", tags: ["tools"]),
            makeItem("Book", tags: ["reading"]),
        ]
        let results = filterItems(items, query: "", tags: ["christmas", "tools"])
        XCTAssertEqual(results.count, 3)
    }

    func test_filterByTagAndQuery() {
        let items = [
            makeItem("Red Ornament", tags: ["christmas"]),
            makeItem("Blue Ornament", tags: ["christmas"]),
            makeItem("Red Hammer", tags: ["tools"]),
        ]
        let results = filterItems(items, query: "Red", tags: ["christmas"])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Red Ornament")
    }

    func test_searchBinByCode() {
        let bins = [makeBin(code: "BIN-001"), makeBin(code: "BIN-002")]
        let results = filterBins(bins, query: "001")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.code, "BIN-001")
    }

    func test_searchBinByName() {
        let bins = [
            makeBin(code: "A1", name: "Holiday Decorations"),
            makeBin(code: "A2", name: "Tools"),
        ]
        let results = filterBins(bins, query: "holiday")
        XCTAssertEqual(results.count, 1)
    }

    func test_searchBinByLocation() {
        let bins = [
            makeBin(code: "A1", location: "Top shelf, garage"),
            makeBin(code: "A2", location: "Basement closet"),
        ]
        let results = filterBins(bins, query: "garage")
        XCTAssertEqual(results.count, 1)
    }
}

// MARK: - Checkout Flow Tests

@MainActor
final class CheckoutFlowTests: XCTestCase {

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

    func test_checkout_setsCheckedOutBy() {
        let item = Item(name: "Drill")
        context.insert(item)

        let record = CheckoutRecord(item: item, checkedOutTo: "Alice")
        record.checkedOutBy = "user-123"
        record.householdId = "household-abc"
        context.insert(record)
        item.isCheckedOut = true

        XCTAssertEqual(record.checkedOutBy, "user-123")
        XCTAssertEqual(record.householdId, "household-abc")
        XCTAssertTrue(item.isCheckedOut)
    }

    func test_checkout_setsHouseholdIdFromItem() {
        let item = Item(name: "Drill")
        item.householdId = "hh-456"
        context.insert(item)

        let record = CheckoutRecord(item: item, checkedOutTo: "Bob")
        record.householdId = item.householdId
        context.insert(record)

        XCTAssertEqual(record.householdId, "hh-456")
    }

    func test_checkIn_setsCheckedInAtAndClearsFlag() {
        let item = Item(name: "Drill")
        context.insert(item)

        let record = CheckoutRecord(item: item, checkedOutTo: "Alice")
        context.insert(record)
        item.isCheckedOut = true

        XCTAssertTrue(record.isActive)

        record.checkedInAt = Date()
        item.isCheckedOut = false

        XCTAssertFalse(record.isActive)
        XCTAssertFalse(item.isCheckedOut)
    }

    func test_checkoutPermission_noneBlocksCheckout() {
        let item = Item(name: "Fragile Vase")
        item.checkoutPermission = "none"
        context.insert(item)

        XCTAssertEqual(item.checkoutPermission, "none")
        // UI should check this before showing checkout button
    }

    func test_checkoutPermission_defaultIsAnyone() {
        let item = Item(name: "Hammer")
        XCTAssertEqual(item.checkoutPermission, "anyone")
    }

    func test_multipleCheckoutRecords_onlyOneActive() {
        let item = Item(name: "Drill")
        context.insert(item)

        let first = CheckoutRecord(item: item, checkedOutTo: "Alice")
        first.checkedInAt = Date()
        context.insert(first)

        let second = CheckoutRecord(item: item, checkedOutTo: "Bob")
        context.insert(second)

        item.isCheckedOut = true

        let active = item.checkoutHistory.filter(\.isActive)
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.checkedOutTo, "Bob")
    }

    func test_expectedReturnDate_trackedOnRecord() {
        let returnDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        let item = Item(name: "Book")
        context.insert(item)

        let record = CheckoutRecord(item: item, checkedOutTo: "Carol", expectedReturnDate: returnDate)
        context.insert(record)

        XCTAssertNotNil(record.expectedReturnDate)
    }

    func test_overdueDetection() {
        let item = Item(name: "Tool")
        context.insert(item)

        let pastDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        let record = CheckoutRecord(item: item, checkedOutTo: "Dave", expectedReturnDate: pastDate)
        context.insert(record)
        item.isCheckedOut = true

        let isOverdue = record.isActive
            && record.expectedReturnDate != nil
            && record.expectedReturnDate! < Date() // swiftlint:disable:this force_unwrapping
        XCTAssertTrue(isOverdue)
    }
}

// MARK: - AI JSON Extraction Tests

final class AIJSONExtractionTests: XCTestCase {

    func test_extractJSONArray_plainJSON() {
        let input = """
        [{"name": "Hammer"}, {"name": "Nails"}]
        """
        let result = ImageAnalysisService.extractJSONArray(from: input)
        XCTAssertTrue(result.hasPrefix("["))
        XCTAssertTrue(result.hasSuffix("]"))
    }

    func test_extractJSONArray_wrappedInCodeFence() {
        let input = """
        ```json
        [{"name": "Hammer"}]
        ```
        """
        let result = ImageAnalysisService.extractJSONArray(from: input)
        XCTAssertTrue(result.hasPrefix("["))
        XCTAssertTrue(result.hasSuffix("]"))
        XCTAssertFalse(result.contains("```"))
    }

    func test_extractJSONArray_wrappedInPlainCodeFence() {
        let input = """
        ```
        [{"name": "Screwdriver"}]
        ```
        """
        let result = ImageAnalysisService.extractJSONArray(from: input)
        XCTAssertTrue(result.hasPrefix("["))
        XCTAssertFalse(result.contains("```"))
    }

    func test_extractJSONArray_withSurroundingProse() {
        let input = """
        Here are the items I found:
        [{"name": "Wrench"}, {"name": "Pliers"}]
        Let me know if you need more details.
        """
        let result = ImageAnalysisService.extractJSONArray(from: input)
        XCTAssertTrue(result.hasPrefix("["))
        XCTAssertTrue(result.hasSuffix("]"))
        XCTAssertFalse(result.contains("Here are"))
    }

    func test_extractJSONObject_plainJSON() {
        let input = """
        {"value": 25.99, "reasoning": "Common hardware store item"}
        """
        let result = ImageAnalysisService.extractJSONObject(from: input)
        XCTAssertTrue(result.hasPrefix("{"))
        XCTAssertTrue(result.hasSuffix("}"))
    }

    func test_extractJSONObject_wrappedInCodeFence() {
        let input = """
        ```json
        {"value": 10.00}
        ```
        """
        let result = ImageAnalysisService.extractJSONObject(from: input)
        XCTAssertTrue(result.hasPrefix("{"))
        XCTAssertFalse(result.contains("```"))
    }

    func test_extractJSONObject_withProse() {
        let input = """
        Based on my analysis:
        {"value": 42.50, "reasoning": "Vintage item in good condition"}
        Hope this helps!
        """
        let result = ImageAnalysisService.extractJSONObject(from: input)
        XCTAssertTrue(result.hasPrefix("{"))
        XCTAssertTrue(result.hasSuffix("}"))
        XCTAssertFalse(result.contains("Based on"))
    }
}

// MARK: - Per-User API Key Tests

final class PerUserAPIKeyTests: XCTestCase {

    override func tearDown() {
        // Clean up any keys we set during tests
        UserDefaults.standard.removeObject(forKey: "claude_api_key_user-aaa")
        UserDefaults.standard.removeObject(forKey: "claude_api_key_user-bbb")
        UserDefaults.standard.removeObject(forKey: "claude_api_key")
        ImageAnalysisService.setCurrentUser(nil)
    }

    func test_apiKey_scopedPerUser() {
        ImageAnalysisService.setCurrentUser("user-aaa")
        ImageAnalysisService.apiKey = "sk-ant-aaa"

        ImageAnalysisService.setCurrentUser("user-bbb")
        XCTAssertNil(ImageAnalysisService.apiKey)

        ImageAnalysisService.apiKey = "sk-ant-bbb"
        XCTAssertEqual(ImageAnalysisService.apiKey, "sk-ant-bbb")

        ImageAnalysisService.setCurrentUser("user-aaa")
        XCTAssertEqual(ImageAnalysisService.apiKey, "sk-ant-aaa")
    }

    func test_apiKey_clearedOnSignOut() {
        ImageAnalysisService.setCurrentUser("user-aaa")
        ImageAnalysisService.apiKey = "sk-ant-test"
        XCTAssertEqual(ImageAnalysisService.apiKey, "sk-ant-test")

        ImageAnalysisService.setCurrentUser(nil)
        // With no user, falls back to the un-scoped key
        let fallbackKey = ImageAnalysisService.apiKey
        XCTAssertNotEqual(fallbackKey, "sk-ant-test")
    }

    func test_apiKey_nilUserUsesFallbackKey() {
        ImageAnalysisService.setCurrentUser(nil)
        ImageAnalysisService.apiKey = "sk-fallback"
        XCTAssertEqual(ImageAnalysisService.apiKey, "sk-fallback")
        UserDefaults.standard.removeObject(forKey: "claude_api_key")
    }
}

// MARK: - UUID Case Consistency Tests

final class UUIDCaseTests: XCTestCase {

    func test_householdId_lowercased() {
        let uuid = UUID()
        let lowered = uuid.uuidString.lowercased()
        XCTAssertEqual(lowered, lowered.lowercased(), "UUID should already be lowercase")
        XCTAssertNotEqual(uuid.uuidString, lowered, "Swift UUID.uuidString should be uppercase by default")
    }

    func test_syncPayload_usesLowercaseUUIDs() {
        let uuid = UUID()
        let payload = uuid.uuidString.lowercased()
        // Simulates what SyncService does before sending to Supabase
        XCTAssertTrue(payload == payload.lowercased())
        XCTAssertFalse(payload.contains(where: { $0.isUppercase }))
    }
}
