# App Store Connect Listing — binthere

Copy-paste fields for App Store Connect submission. Update version-specific
fields ("What's New") for each release.

---

## App Name (30 chars max)

binthere

## Subtitle (30 chars max)

Never lose your stuff again

## Promotional Text (170 chars max, can be updated without resubmission)

Snap a photo and let AI catalog your bins, drawers, and storage. Scan a QR code to instantly see what's inside. Stop digging — start finding.

## Description (4000 chars max)

Where the heck did you put it?

binthere is a beautifully simple way to keep track of every physical thing you own — the holiday decorations in the attic, the cables in the junk drawer, the tools in the garage, the kid's outgrown clothes in the basement.

Snap a photo of a bin's contents, and AI does the rest. It identifies each item, names it, describes it, tags it, and even estimates what it's worth. You review, edit, and save — no tedious typing.

Each bin gets a printable QR code label. Stick it on the box. Scan it later and you instantly see everything inside, right on your phone.

KEY FEATURES

• AI-powered cataloging — point your camera at a bin, get a complete inventory in seconds
• QR code labels — generate, print, scan. No more guessing what's in the box.
• Zones — group bins by room, garage, attic, storage unit, anywhere
• Check items in and out — borrow a tool, lend a book, track who has what
• Bulk value estimation — let AI estimate the total value of a bin or zone for insurance, moves, or downsizing
• Tags, colors, custom fields — organize the way that makes sense to you
• Search across everything — find any item across every bin in seconds
• Share with your household — partners and roommates see the same inventory in real time
• Reports & analytics — total value, item counts, what's overdue to come back
• Photos for every item — visual confirmation, not just words
• Works offline — your inventory is on your device first, synced second
• Privacy-first — your data is yours. No ads. No tracking. No selling.

PERFECT FOR

• Anyone with a garage, basement, attic, or storage unit
• Families managing seasonal stuff (holiday, sports, hobbies)
• Hobbyists with parts, tools, supplies, and components
• People preparing for a move
• Estate organization and downsizing
• Insurance documentation
• Renters tracking what's in storage

WHY BINTHERE?

Because "I know I have one of those somewhere" is the most expensive sentence in your house. You buy duplicates. You waste hours digging. You forget what you own. binthere fixes that — once.

Set it up over a weekend with the AI scan, and from then on every container is a tap away.

PRIVACY

binthere stores your inventory securely in your account. We don't sell your data, show you ads, or track you. Photos you take are stored in your account so you can access them across your devices. AI analysis is done on-demand and never used to train external models. Read the full privacy policy at [your privacy URL].

Built by one developer who got tired of saying "where the f—— is that thing?" Welcome to never losing it again.

## Keywords (100 chars max, comma separated, no spaces)

inventory,storage,organize,QR,bins,home,declutter,catalog,moving,attic,garage,closet,stuff,items

## Support URL

https://patrickisgreat.github.io/binthere/

## Marketing URL (optional)

https://patrickisgreat.github.io/binthere/

## Privacy Policy URL

https://patrickisgreat.github.io/binthere/privacy.html

## Category

Primary: Productivity
Secondary: Lifestyle

## Age Rating

4+

## Copyright

© 2026 Patrick Bennett

---

## What's New (4000 chars max, per release)

### 1.0.0

Welcome to binthere! The first release.

• AI-powered bin cataloging — snap a photo, get every item identified, named, tagged, and valued
• QR code labels for every bin
• Zones to group bins by location
• Check items in and out
• Household sharing — sync your inventory with partners and roommates
• Reports and analytics — total value, item counts, search across everything
• Sign in with Apple, Google, or email
• Offline-first with cloud sync

---

## App Review Information

### Demo Account

Email: appreview@binthere.app
Password: BinThereReview2026!

NOTE: this account is pre-confirmed — no email verification step needed. It is seeded with one zone (Garage), one bin (Holiday Decorations), and three sample items so the reviewer can see real data immediately on first launch. Created by `supabase/migrations/005_seed_app_review_user.sql`.

### Notes for Reviewer

binthere is a personal inventory app. To exercise the full flow:

1. Sign in with the demo account above
2. The account has a pre-populated household with one zone, one bin, and a few items
3. Tap the bin to see its contents
4. Try the AI scan feature: tap the camera button on a bin, take a photo of any objects, and the app will identify and catalog them
   • AI features require an Anthropic API key. The demo account has one configured in Settings.
5. Print or display the QR code on a bin and scan it from the Scan tab to verify QR routing

The Sign in with Apple flow uses Supabase as the backend.

Account deletion fully removes the user's auth record, household memberships, and all owned data — confirmed via the Delete Account button in Settings.

### Contact Info

First Name: Patrick
Last Name: Bennett
Phone: [your phone]
Email: patrickisgreat@gmail.com

---

## Privacy "Nutrition Label" Questionnaire

Apple asks what data your app collects, whether it's linked to the user's identity, and whether it's used for tracking. Answer in App Store Connect → App Privacy.

### Data Collected

**Contact Info → Email Address**
- Linked to user: YES
- Used for tracking: NO
- Purposes: App Functionality (account login)

**User Content → Photos**
- Linked to user: YES
- Used for tracking: NO
- Purposes: App Functionality (storing item photos in their inventory)

**User Content → Other User Content** (item names, descriptions, tags, values)
- Linked to user: YES
- Used for tracking: NO
- Purposes: App Functionality

**Identifiers → User ID** (Supabase auth UUID)
- Linked to user: YES
- Used for tracking: NO
- Purposes: App Functionality

### Data NOT Collected

- Location (no GPS or IP location)
- Contacts
- Health & Fitness
- Financial Info (item values are user-entered estimates, not real financial data)
- Browsing History
- Search History
- Device ID for tracking
- Advertising Data
- Diagnostic Data sent to third parties

### Tracking

NO. binthere does not track users across apps or websites owned by other companies. There is no advertising SDK, no analytics SDK that does cross-app tracking, and no data is shared with data brokers.

### Third-Party Data Use

- **Supabase**: hosts the database and auth. Bound by Supabase's DPA. Data is in your project, not pooled.
- **Anthropic API (Claude)**: when the user invokes AI scan, the photo and a prompt are sent to Anthropic for one-shot inference. Anthropic does not train on API data. Photos are not retained beyond the request lifecycle.
- **Apple Push Notification Service**: standard APNs for reminders.

---

## Export Compliance

ITSAppUsesNonExemptEncryption: NO

binthere uses only standard HTTPS and Apple-provided cryptography. No proprietary encryption.

---

## Screenshots

Located in `screens/`:

- 01-household-setup.png
- 02-bins-list.png
- 03-bins-menu.png
- 04-bin-empty.png
- 05-bin-items.png
- 06-set-value.png
- 07-item-detail.png
- 08-zones-grid.png
- 09-zone-detail.png
- 10-zone-settings.png
- 11-qr-label.png
- 12-settings.png
- 13-settings-detail.png
- 14-reports.png
- 15-analytics.png
- 16-analytics-charts.png

Apple required sizes:
- 6.7" iPhone (iPhone 17 Pro Max / 16 Pro Max): 1290 × 2796 px — REQUIRED
- 6.5" iPhone (older Plus/Max models): 1242 × 2688 px — recommended
- iPad Pro 13": 2064 × 2752 px — only if iPad is supported
