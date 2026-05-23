# CloudKit / SQLiteData Schema Design (Phase 2)

Target data layer: **SQLiteData + CloudKit**. This doc defines the corrected schema that
satisfies CloudKit sharing and replaces the current SwiftData `@Model` types.

## The constraint that drives everything

SQLiteData can only share **root records (no foreign keys)**. A child record is included in a
share only if it has **exactly one** foreign key pointing toward the root, recursively. The current
schema fails this: every table carries a denormalized `householdId` *plus* a relationship FK, i.e.
two FKs → not shareable.

Fix: a strict single-parent tree rooted at `Household`. Membership is implied by tree position, so
the denormalized `householdId` is removed from every child.

```
Household              (root — NO foreign keys; this is the shared record)
└─ Zone                (FK → householdID)
   └─ Bin              (FK → zoneID)
      └─ Item          (FK → binID)
         ├─ CheckoutRecord    (FK → itemID)
         └─ CustomAttribute   (FK → itemID)
```

## Resolved product decisions (my picks — override if you disagree)

1. **Every Bin lives in a Zone.** Today `Bin.zone` is optional. The tree needs one parent per bin,
   so on household creation we auto-create a default **"Unsorted"** zone, and bins with no
   explicit zone go there. UX is unchanged (users can ignore zones); under the hood every bin has a
   zone parent. "Remove bin from zone" becomes "move to Unsorted."
2. **Every Item lives in a Bin.** Same reasoning. Auto-create a default **"Loose Items"** bin in the
   Unsorted zone for items not explicitly placed in a bin. (If we confirm the app never creates
   bin-less items, we can instead make `binID` non-optional and skip the default bin.)

Rationale: this keeps the rich `Zone` model (color/icon/locations) and the existing 4-level mental
model intact, costs only two invisible default rows per household, and avoids giving any table two
parent FKs.

## `@Table` types

SQLiteData tables are plain structs; relationships live in the SQL schema (next section), not in the
Swift types. Arrays and dictionaries serialize to JSON text columns.

```swift
import Foundation
import SQLiteData

@Table
nonisolated struct Household: Identifiable {
  let id: UUID
  var name = ""
  var spaceType = "home"
  var createdBy = ""            // owner's CloudKit/user ref, for display only — NOT an FK
  var createdAt = Date()
  // Household-wide AI config (was PR #67's shared key). On the shared root it syncs to all
  // members for free — no RLS, no separate table, no owner-only write policy needed.
  var aiProvider = "anthropic"
  var apiKey: String?
}

@Table
nonisolated struct Zone: Identifiable {
  let id: UUID
  var householdID: UUID         // the one FK toward the root
  var name = ""
  var locationDescription = ""
  var color = ""
  var icon = ""
  var locations: [String] = []  // JSON column
  var updatedAt = Date()
}

@Table
nonisolated struct Bin: Identifiable {
  let id: UUID
  var zoneID: UUID              // the one FK
  var code = ""
  var name = ""
  var binDescription = ""
  var location = ""
  var color = ""
  var qrCodeImagePath: String?
  var contentImagePaths: [String] = []  // JSON column (see Images note)
  var createdAt = Date()
  var updatedAt = Date()
}

@Table
nonisolated struct Item: Identifiable {
  let id: UUID
  var binID: UUID              // the one FK
  var name = ""
  var itemDescription = ""
  var imagePaths: [String] = []          // JSON column (see Images note)
  var tags: [String] = []                // JSON column
  var customFields: [String: String] = [:] // JSON column
  var color = ""
  var notes = ""
  var value: Double?
  var valueSource = ""
  var valueUpdatedAt: Date?
  var isCheckedOut = false
  var createdBy = ""           // user ref, display only — NOT an FK
  var checkoutPermission = "anyone"
  var allowedCheckoutUsers: [String] = [] // JSON column
  var maxCheckoutDays: Int?
  var createdAt = Date()
  var updatedAt = Date()
}

@Table
nonisolated struct CheckoutRecord: Identifiable {
  let id: UUID
  var itemID: UUID             // the one FK
  var checkedOutAt = Date()
  var checkedInAt: Date?
  var checkedOutTo = ""
  var checkedOutBy = ""
  var notes = ""
  var expectedReturnDate: Date?
}

@Table
nonisolated struct CustomAttribute: Identifiable {
  let id: UUID
  var itemID: UUID             // the one FK
  var name = ""
  var type = "text"
  var textValue = ""
  var numberValue: Double?
  var dateValue: Date?
  var boolValue = false
  var sortOrder = 0
}
```

## SQLite migration

`STRICT` tables, UUID text primary keys defaulting to `uuid()`, FKs with `ON DELETE CASCADE` to
mirror the current SwiftData `.cascade` rules (and `.nullify` is gone — every child now has a hard
parent).

```sql
CREATE TABLE "households" (
  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
  "name" TEXT NOT NULL DEFAULT '',
  "spaceType" TEXT NOT NULL DEFAULT 'home',
  "createdBy" TEXT NOT NULL DEFAULT '',
  "createdAt" TEXT NOT NULL DEFAULT (datetime('now')),
  "aiProvider" TEXT NOT NULL DEFAULT 'anthropic',
  "apiKey" TEXT
) STRICT;

CREATE TABLE "zones" (
  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
  "householdID" TEXT NOT NULL REFERENCES "households"("id") ON DELETE CASCADE,
  "name" TEXT NOT NULL DEFAULT '',
  "locationDescription" TEXT NOT NULL DEFAULT '',
  "color" TEXT NOT NULL DEFAULT '',
  "icon" TEXT NOT NULL DEFAULT '',
  "locations" TEXT NOT NULL DEFAULT '[]',
  "updatedAt" TEXT NOT NULL DEFAULT (datetime('now'))
) STRICT;

CREATE TABLE "bins" (
  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
  "zoneID" TEXT NOT NULL REFERENCES "zones"("id") ON DELETE CASCADE,
  "code" TEXT NOT NULL DEFAULT '',
  "name" TEXT NOT NULL DEFAULT '',
  "binDescription" TEXT NOT NULL DEFAULT '',
  "location" TEXT NOT NULL DEFAULT '',
  "color" TEXT NOT NULL DEFAULT '',
  "qrCodeImagePath" TEXT,
  "contentImagePaths" TEXT NOT NULL DEFAULT '[]',
  "createdAt" TEXT NOT NULL DEFAULT (datetime('now')),
  "updatedAt" TEXT NOT NULL DEFAULT (datetime('now'))
) STRICT;

CREATE TABLE "items" (
  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
  "binID" TEXT NOT NULL REFERENCES "bins"("id") ON DELETE CASCADE,
  "name" TEXT NOT NULL DEFAULT '',
  "itemDescription" TEXT NOT NULL DEFAULT '',
  "imagePaths" TEXT NOT NULL DEFAULT '[]',
  "tags" TEXT NOT NULL DEFAULT '[]',
  "customFields" TEXT NOT NULL DEFAULT '{}',
  "color" TEXT NOT NULL DEFAULT '',
  "notes" TEXT NOT NULL DEFAULT '',
  "value" REAL,
  "valueSource" TEXT NOT NULL DEFAULT '',
  "valueUpdatedAt" TEXT,
  "isCheckedOut" INTEGER NOT NULL DEFAULT 0,
  "createdBy" TEXT NOT NULL DEFAULT '',
  "checkoutPermission" TEXT NOT NULL DEFAULT 'anyone',
  "allowedCheckoutUsers" TEXT NOT NULL DEFAULT '[]',
  "maxCheckoutDays" INTEGER,
  "createdAt" TEXT NOT NULL DEFAULT (datetime('now')),
  "updatedAt" TEXT NOT NULL DEFAULT (datetime('now'))
) STRICT;

CREATE TABLE "checkoutRecords" (
  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
  "itemID" TEXT NOT NULL REFERENCES "items"("id") ON DELETE CASCADE,
  "checkedOutAt" TEXT NOT NULL DEFAULT (datetime('now')),
  "checkedInAt" TEXT,
  "checkedOutTo" TEXT NOT NULL DEFAULT '',
  "checkedOutBy" TEXT NOT NULL DEFAULT '',
  "notes" TEXT NOT NULL DEFAULT '',
  "expectedReturnDate" TEXT
) STRICT;

CREATE TABLE "customAttributes" (
  "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
  "itemID" TEXT NOT NULL REFERENCES "items"("id") ON DELETE CASCADE,
  "name" TEXT NOT NULL DEFAULT '',
  "type" TEXT NOT NULL DEFAULT 'text',
  "textValue" TEXT NOT NULL DEFAULT '',
  "numberValue" REAL,
  "dateValue" TEXT,
  "boolValue" INTEGER NOT NULL DEFAULT 0,
  "sortOrder" INTEGER NOT NULL DEFAULT 0
) STRICT;
```

## Old SwiftData → new table mapping

| Old (SwiftData)                         | New                                  | Change |
|-----------------------------------------|--------------------------------------|--------|
| `Household` (Codable struct, Supabase)  | `Household` `@Table`                 | Becomes a real local+synced root record; absorbs `aiProvider`/`apiKey` from PR #67 |
| `Zone.householdId: String`              | `Zone.householdID: UUID` (FK)         | Denormalized string → real FK to root |
| `Bin.householdId` + `Bin.zone?`         | `Bin.zoneID: UUID` (FK)               | Two parents → one; zone now required (default "Unsorted") |
| `Item.householdId` + `Item.bin?`        | `Item.binID: UUID` (FK)               | Two parents → one; bin now required (default "Loose Items") |
| `CheckoutRecord.householdId` + `.item?` | `CheckoutRecord.itemID: UUID` (FK)    | Two parents → one |
| `CustomAttribute.householdId` + `.item?`| `CustomAttribute.itemID: UUID` (FK)   | Two parents → one |
| `@Relationship(.cascade/.nullify)`      | SQL `ON DELETE CASCADE`               | Delete rules move into the schema |
| `[String]`, `[String:String]`           | JSON text columns                     | SQLite has no array type |

## Images (deferred to its own step)

Today images are local files referenced by path (`imagePaths`, `qrCodeImagePath`,
`contentImagePaths`) and won't sync. SQLiteData "handles large binary assets in the background"
(→ CloudKit `CKAsset`). Plan: store image **bytes** as `BLOB` columns directly on `Item`/`Bin`
rather than a separate attachment table — a per-owner attachment table would need to point at
either an item or a bin (two possible FKs), which violates the single-FK rule. Inline blobs keep the
tree clean. Migrating the existing path-based pipeline is a dedicated step after the core schema
lands. No user data to migrate (no users yet).

## Deferred / open

- **Account deletion & ownership transfer** for shared households (data lives in the owner's
  iCloud; if the owner deletes, members lose access). Design when we wire sharing.
- **Identity**: `createdBy` / `checkedOutBy` currently hold Supabase user IDs; remap to CloudKit
  participant IDs once sharing is in.
- Confirm whether bin-less items are a real flow; if not, drop the default "Loose Items" bin and
  make `binID` strictly required at creation.
```
