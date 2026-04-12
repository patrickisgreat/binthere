# binthere — Roadmap

## Completed

### Phase 1: Core App Foundation
- SwiftData models (Bin, Item, Zone, CheckoutRecord)
- Tab-based navigation (Bins, Scan, Settings)
- QR code scanning and generation
- Item CRUD with photos
- AI-powered item detection from photos (Claude API)
- Check-in/check-out flow
- Unit tests, CI/CD, SwiftLint

### Phase 2: Bin Identity Overhaul + Color Coding
- Auto-generated 4-char bin codes (e.g. D4J6)
- Color coding for bins and items
- Redesigned QR labels with large readable code
- Share and print QR labels
- Simplified bin creation flow

### Phase 3: Zone Overhaul + Smart Home Import
- Zone colors and SF Symbol icons
- Zone detail view with bin listing
- HomeKit room import (one-time)
- Group-by-zone in bin list
- Icon picker with 24 preset symbols

## Up Next

### Phase 4: NFC Support
- Scan NFC tags to open bins/items (Core NFC)
- Write bin UUID to NFC tags
- NFC as alternative to QR for smaller items

### Phase 5: Item Enrichment
- Custom attributes on items/bins (beyond key-value)
- Object notes (rich text)
- Valuations: manual input, AI estimation, or combined
- Total valuation rollups per bin/zone/overall

### Phase 6: Reports & Printing
- Print bin manifests (itemized contents list)
- Insurance reports (items with photos, valuations, locations)
- Graphical reports (Swift Charts — value by zone, checkout frequency)

### Phase 7: Multi-User & Permissions
- Invite users to your household
- Per-bin or per-item permission levels (view, checkout, manage)
- Checkout auto-populates current user's name
- Item creators set constraints: who can check out, max duration, availability
- See who has what checked out and expected return dates
- Ping household members to return items

### Phase 8: Notifications
- Items due back reminders (UserNotifications + APNs)
- "Someone needs this item" push to current holder
- Checkout/checkin activity feed

### Phase 9: Operations & Polish
- Bulk select / edit / delete
- Move entire bins between zones
- Improved item move UX
- Search improvements (filters, saved searches)

### Phase 10: Sync & Backend
- Supabase backend (Auth, PostgreSQL, Storage)
- Multi-device sync via Supabase
- Offline-first with conflict resolution
- Row Level Security for household isolation

### Phase 11: UI/UX Overhaul — Things-Inspired Design
Redesign the app's visual language and interaction patterns to match the polish and feel of [Things 3](https://culturedcode.com/things/) by Cultured Code:

- **Clean, minimal chrome** — reduce visual noise, let content breathe with generous whitespace and subtle separators instead of heavy section borders
- **Smooth animations** — spring-based transitions for sheet presentations, item additions/deletions, and navigation. Everything should feel fluid and intentional.
- **Custom navigation** — replace default NavigationStack push with Things-style full-screen detail views that slide up as cards/sheets
- **Inline editing** — tap a field to edit in-place (no separate edit mode). Text fields that look like labels until tapped.
- **Drag and drop** — reorder items within bins, move items between bins via drag
- **Quick add** — persistent "Add Item" row at the bottom of bin detail (like Things' quick entry), not hidden behind a + button and sheet
- **Haptic feedback** — subtle haptics on check-in/check-out, item creation, drag actions
- **Typography** — SF Pro with clear hierarchy: large bold titles, medium body, light metadata. No visual clutter.
- **Color system** — refined palette with muted backgrounds, vibrant accents only on interactive elements and color dots
- **Dark mode polish** — proper dark mode with true black backgrounds and adjusted color palette (not just inverted)
- **Empty states** — illustrated/branded empty states instead of generic SF Symbol + text
- **Pull to refresh** — even though data is local, the gesture should feel natural for future sync
- **Swipe gestures** — rich swipe actions (check out, move, delete) with color-coded backgrounds like Things' swipe-to-complete
- **Contextual menus** — long-press context menus on items and bins for quick actions
- **Keyboard shortcuts** — for iPad: Cmd+N (new bin), Cmd+F (search), etc.
- **Accessibility** — VoiceOver labels, Dynamic Type support, reduce motion preferences

## Ideas (Unprioritized)
- Apple Home / Google Home room live sync
- Barcode scanning for commercial products
- Item templates / categories
- Export data (CSV, JSON)
- iPad layout optimizations
- Apple Watch companion (quick scan + checkout)
- Siri Shortcuts integration
- Widget for recently checked out items
