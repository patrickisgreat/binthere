---
layout: default
title: Privacy Policy
---

# Privacy Policy

**Last updated: April 14, 2026**

binthere ("we", "our", or "the app") is a personal inventory management app. This privacy policy explains what data we collect, how we use it, and your rights.

## What We Collect

### Account Information
- **Email address** — used for authentication when you sign up with email
- **Display name** — the name you choose when creating or joining a household

When you sign in with Apple or Google, we receive only the information you authorize (typically email). We do not access your Apple ID password or Google account password.

### Inventory Data
- Bin names, codes, descriptions, and locations
- Item names, descriptions, tags, notes, and valuations
- Photos of items and bin contents (stored locally on your device and optionally synced to our cloud service)
- Checkout records (who has what and when)
- Zone/room organization data

### Device Permissions
- **Camera** — to scan QR codes, take photos of items and bins
- **NFC** — to read and write NFC tags on bins
- **HomeKit** — to import room names as zones (read-only, one-time)
- **Notifications** — to send checkout reminders

We only access these when you explicitly grant permission. You can revoke access at any time in iOS Settings.

## How We Use Your Data

- To provide the app's core functionality (organizing, tracking, and finding your stuff)
- To sync data across your devices
- To share inventory data with members of your household
- To send checkout reminder notifications

We do **not**:
- Sell your data to third parties
- Use your data for advertising
- Track your location
- Share your data outside your household

## AI Features

When you use AI-powered item detection or value estimation, photos and item descriptions are sent to the Claude API (by Anthropic) for analysis. This data is processed according to [Anthropic's privacy policy](https://www.anthropic.com/privacy). Photos are sent only when you explicitly trigger the AI feature — never automatically.

## Data Storage

- **Local storage**: All data is stored on your device using SwiftData
- **Cloud sync**: When signed in, data is synced via Supabase (hosted on AWS). Data is encrypted in transit (TLS) and at rest
- **Photos**: Stored locally in the app's documents directory and optionally synced to Supabase Storage

## Data Retention

Your data is retained as long as you have an active account. You can delete your account and all associated data at any time from **Settings → Delete Account**.

## Your Rights

- **Access**: You can view all your data within the app
- **Export**: Use the CSV export feature to download your inventory data
- **Deletion**: Delete your account and all data from Settings
- **Portability**: Export your data as CSV at any time

## Children's Privacy

binthere is not intended for children under 13. We do not knowingly collect data from children.

## Changes to This Policy

We may update this policy from time to time. Updates will be posted on this page with a revised date.

## Contact

If you have questions about this privacy policy, contact us at:

**Email**: patrick@beebetter.dev

---

*binthere is developed by Patrick Bennett.*
