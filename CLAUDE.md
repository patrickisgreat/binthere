# CLAUDE.md — binthere

## What is this project?

binthere is a native iOS app for tracking physical items stored in bins, drawers, and containers. Users scan a QR code on a bin to instantly see its contents, add items with photos (with AI-powered auto-description), check items in/out, and get reminders to return borrowed items. The goal: never say "where the fuck is this?" again.

## Requirements

1. Scan a QR code on a bin and see what's in it
2. Store pictures of items and associate them to item records
3. AI analyzes photos of bin contents and pre-fills item data (user verifies/edits)
4. Check an item out of a bin
5. Check an item back into a bin
6. Bins have metadata (zone, location, description)
7. Reminders to check items back in
8. Notifications to people who have something checked out
9. Remove items from the system (sold, damaged, etc.)
10. Move items between bins
11. Custom fields and tags on items

## Tech Stack

- **UI**: SwiftUI (iOS 17+)
- **Data**: SwiftData (local persistence)
- **Backend**: Supabase (Auth, PostgreSQL, Storage) for sync and multi-device support
- **AI/Vision**: Apple Vision framework for on-device image analysis, Claude API for detailed item description
- **QR**: AVFoundation for camera-based QR scanning
- **Notifications**: UserNotifications framework + APNs
- **Package Manager**: Swift Package Manager (SPM)
- **Testing**: XCTest (unit + integration), XCUITest (UI tests)
- **CI/CD**: GitHub Actions + Xcode Cloud
- **Minimum Target**: iOS 17.0

## Common Commands

```bash
# Build & run from command line
xcodebuild -scheme binthere -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run unit tests
xcodebuild test -scheme binthere -destination 'platform=iOS Simulator,name=iPhone 16'

# Run UI tests
xcodebuild test -scheme binthereUITests -destination 'platform=iOS Simulator,name=iPhone 16'

# SwiftLint (once added)
swiftlint lint --strict

# SwiftFormat (once added)
swiftformat --lint .
```

## Project Structure

```
binthere/
├── App/
│   └── binthereApp.swift              # App entry point, ModelContainer setup
├── Models/
│   ├── Bin.swift                      # Bin model (QR code, zone, location, items)
│   ├── Item.swift                     # Item model (name, description, photos, tags, custom fields)
│   ├── CheckoutRecord.swift           # Check-in/check-out history
│   └── Zone.swift                     # Zone/location grouping
├── Views/
│   ├── ContentView.swift              # Root navigation
│   ├── Bins/                          # Bin list, detail, creation views
│   ├── Items/                         # Item list, detail, creation, edit views
│   ├── Scanner/                       # QR scanner view
│   ├── Camera/                        # Image capture and picker
│   └── Settings/                      # App settings, zones management
├── ViewModels/                        # ObservableObject view models (if needed beyond @Observable)
├── Services/
│   ├── ImageAnalysisService.swift     # AI-powered image analysis
│   ├── QRService.swift                # QR code generation and scanning logic
│   ├── NotificationService.swift      # Local + push notification scheduling
│   ├── SyncService.swift              # Supabase sync
│   └── StorageService.swift           # Image storage (local + Supabase Storage)
├── Utilities/
│   ├── Extensions/                    # Swift/SwiftUI extensions
│   └── Helpers/                       # Shared utility functions
├── Resources/
│   └── Assets.xcassets                # App icons, colors, images
├── Preview Content/                   # SwiftUI preview assets
binthereTests/                         # Unit + integration tests
binthereUITests/                       # UI tests (XCUITest)
```

## Architecture

### SwiftUI + SwiftData

This app uses SwiftUI with SwiftData as the primary persistence layer. SwiftData models are the source of truth. Use `@Model` macro for all persistent types. Use `@Query` in views to fetch data reactively.

Do **not** create a custom `PersistentModel` protocol — SwiftData provides this. Use `ModelContext` for all CRUD operations (insert, delete, save). Let SwiftData manage the object lifecycle.

### Navigation

Use `NavigationStack` with programmatic navigation via `NavigationPath`. Avoid the deprecated `NavigationView`.

### State Management

- Use `@Observable` (Observation framework) for view models and service objects — not `ObservableObject`/`@Published` (the older Combine pattern).
- Use `@State` for view-local state.
- Use `@Environment` to inject `ModelContext` and shared services.
- Use `@Query` for SwiftData fetches in views.
- Use `@Bindable` when passing `@Observable` objects to child views that need bindings.

### Image Pipeline

1. User takes photo or picks from library → `UIImage`
2. Image saved to app's documents directory (and optionally Supabase Storage)
3. Image path/URL stored on the `Item` model
4. For AI analysis: image sent to Vision framework for on-device labeling, then optionally to Claude API for richer descriptions
5. AI results presented to user for verification/editing before saving

### QR Code Flow

1. Each `Bin` has a unique UUID
2. QR codes encode the bin's UUID
3. Scanning a QR code looks up the bin by UUID and navigates to its detail view
4. App can generate printable QR code labels for bins

## Environment

Requires a `.env` or `Config.xcconfig` with Supabase credentials. For local-only development, the app should work fully offline with SwiftData — Supabase sync is additive, not required.

Sensitive keys go in `Secrets.xcconfig` (git-ignored). Reference them via `Info.plist` build settings, never hardcode in source.

## Conventions

### Swift Style

- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Use Swift's native naming conventions: `lowerCamelCase` for variables/functions, `UpperCamelCase` for types/protocols.
- Prefer `let` over `var`. Immutability by default.
- Prefer value types (`struct`, `enum`) over reference types (`class`) unless identity semantics are needed (SwiftData `@Model` classes are the exception).
- Use `guard` for early exits. Avoid deeply nested `if let` chains.
- Use Swift's strong type system — avoid `Any`, `AnyObject`, and force casts (`as!`). Use `as?` with proper handling.
- No force unwraps (`!`) in production code. Use `guard let`, `if let`, or provide a default with `??`.
- Mark classes `final` by default. Only remove `final` when you need inheritance.
- Use `private` and `fileprivate` to minimize API surface. Default to the most restrictive access level.
- Use `// MARK: -` to organize code sections within a file.

### SwiftUI Specifics

- Keep views small and composable. Extract subviews into their own types when a view body exceeds ~40 lines.
- Avoid business logic in views. Views should only describe UI and delegate actions to models/services.
- Use SwiftUI's built-in components (`List`, `Form`, `NavigationStack`, `Sheet`, `Alert`) before reaching for custom solutions.
- Prefer `task {}` modifier over `onAppear` for async work.
- Use `@ViewBuilder` for conditional view composition — avoid `AnyView` erasure.

### SwiftData Specifics

- Use `@Model` macro for all persisted types.
- Define relationships explicitly. Use `@Relationship` with appropriate delete rules (`.cascade`, `.nullify`).
- Use `#Predicate` and `FetchDescriptor` for queries — not raw string predicates.
- Perform writes through `ModelContext` — call `context.insert()`, `context.delete()`, and let auto-save handle persistence (or call `context.save()` explicitly for critical operations).

## Code Standards

### Clean Code

- **DRY**: Extract shared logic into reusable functions/extensions. If you see duplication, refactor it.
- **SRP**: Every function, type, and view should do one thing. If a function needs "and" to describe it, split it.
- **Small, focused types**: Keep files short. One primary type per file. Split large views into subview components.
- **Never over-engineer**: Write the minimum code needed to solve the problem correctly. No speculative abstractions or "just in case" code.
- **Naming**: Use descriptive, intention-revealing names. Code should read like prose. Minimize comments by making code self-documenting.
- **No dead code**: Remove unused imports, variables, functions, and commented-out code.

### Error Handling

- Use Swift's `throws`/`try`/`catch` for operations that can fail. Define domain-specific error enums conforming to `Error` and `LocalizedError`.
- Never use empty `catch` blocks. At minimum, log the error.
- Use `Result<Success, Failure>` when you need to pass errors through closures or async boundaries.
- Present user-facing errors with clear, actionable messages — not raw error dumps.

### Security

- Never commit secrets, tokens, or credentials. Use `Secrets.xcconfig` (git-ignored) and reference via build settings.
- Validate and sanitize all user input at system boundaries.
- Use Supabase RLS (Row Level Security) for all database tables.
- Store sensitive user data in Keychain, not UserDefaults.
- Request only the camera/photo permissions you need, when you need them. Explain why in the permission prompt strings.
- Pin Supabase and other network certificates if handling sensitive data.

## Testing

No PR is mergeable without tests that cover the behavior introduced or changed.

### The Testing Pyramid

```
        /\
       /  \
      / UI  \
     /--------\
    /  Integra- \
   /   tion      \
  /----------------\
 /    Unit Tests    \
/--------------------\
```

### Unit Tests (XCTest)

- Every new model, service, and view model gets unit tests.
- Test behavior, not implementation. If your test breaks when you rename an internal variable, it's testing the wrong thing.
- Tests should be fast — no network, no database, no filesystem. Mock external dependencies at boundaries.
- Use SwiftData's in-memory `ModelConfiguration` for tests that need a data layer.
- Name tests descriptively: `test_checkout_setsExpectedReturnDate()` not `testCheckout()`.

### Integration Tests

- Test service boundaries: Supabase interactions, image storage pipeline, notification scheduling.
- Use real SwiftData containers (in-memory) for data layer integration tests.
- Test the contract at the boundary, not the internals.

### UI Tests (XCUITest)

- Cover critical user journeys: scan QR → view bin contents, add item with photo, check item out, check item back in.
- Use accessibility identifiers for element lookup — this doubles as accessibility compliance.
- Never use hard-coded `sleep()`. Use `waitForExistence(timeout:)` and XCTest expectations.
- Tests must be deterministic. A flaky UI test is a broken test.

### What is not an acceptable excuse

- "It's just a small change." — Small changes break things. Small tests are also small.
- "It's hard to test." — Make it testable. Difficulty testing is a design signal.
- "I'll add tests in a follow-up PR." — Tests go in the same PR or the PR does not merge.

## Git Workflow

- **Always work from a feature branch.** Never commit directly to `main`. Use descriptive branch names: `feat/qr-scanner-improvements`, `fix/checkout-date-bug`.
- **Commit often.** Small, frequent commits that each represent a logical unit of work.
- **Conventional commit messages:**
  - `feat:` — New feature or capability
  - `fix:` — Bug fix
  - `refactor:` — Code restructuring with no behavior change
  - `test:` — Adding or updating tests
  - `chore:` — Build, CI, dependency updates, tooling
  - `docs:` — Documentation changes
  - `perf:` — Performance improvements
  - `style:` — Formatting, whitespace (no logic changes)
- **Messages should be concise and meaningful.** Describe _what_ and _why_, not _how_. Example: `feat: add AI-powered item description from photo` not `update Item.swift`.
- **Submit PRs back to `main` using `gh pr create`.** PRs need clear titles with conventional prefixes. Include a summary and test plan.
- **The user will review all PRs before merge.** Do not merge PRs autonomously.
- **NEVER add `Co-Authored-By` or "Generated with Claude Code" to commits or PRs.**
