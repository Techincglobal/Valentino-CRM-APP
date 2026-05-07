# CRM Caller NxtGen — App Report

> Built with Flutter (iOS + Android) + Frappe/ERPNext backend at `sfinax.nxtgenerp.com`

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication & Site Setup](#authentication--site-setup)
3. [Home Screen](#home-screen)
4. [Incoming Call Overlay (Android)](#incoming-call-overlay-android)
5. [Manual Lookup](#manual-lookup)
6. [Pipeline — Leads](#pipeline--leads)
7. [Pipeline — Opportunities](#pipeline--opportunities)
8. [Quotes & Orders](#quotes--orders)
9. [Settings](#settings)
10. [Backend API](#backend-api)
11. [Tech Stack](#tech-stack)

---

## Overview

CRM Caller NxtGen is a mobile CRM companion app that automatically identifies incoming callers by looking them up in Frappe/ERPNext. When a call comes in, a native overlay pops up showing the caller's CRM profile, last note, and quick actions — without leaving whatever the user is doing. The app also provides a full pipeline view (leads → opportunities → quotes → orders) and lets the whole team share notes and contact data in real time.

---

## Authentication & Site Setup

| Step | Detail |
|------|--------|
| **Site URL** | User enters their Frappe server URL on first launch (e.g. `https://sfinax.nxtgenerp.com`) |
| **Login** | Username + password authenticated against Frappe REST API |
| **Session storage** | Credentials and cookies stored locally via `SharedPreferences` |
| **Auto-login** | On relaunch, stored session is validated; user is taken straight to the app if still valid |
| **Sign out** | Clears all local storage and returns to Site Setup screen |

<!-- screenshot: Site Setup screen -->

<!-- screenshot: Login screen -->

---

## Home Screen

The dashboard shown immediately after login.

### Daily Call Counter
- Tracks how many calls have been processed today
- Resets automatically at midnight

### Manual Lookup Card
- Enter any phone number and tap Search
- Fetches caller details from Frappe in real time
- Opens the **Lookup Result Sheet** (see below) — does NOT trigger the overlay

### Overlay Permission Card
- Shows current "Draw Over Apps" permission status
- One-tap button to open Android system settings if permission is missing

### Test Overlay Card
- **Simulate Known Caller** — fires a test overlay with a fake known contact
- **Simulate Unknown Caller** — fires a test overlay with an unknown number (clears local Room cache first so the unknown-call flow is always fresh)

### Recent Notes
- Shows the latest CRM notes saved across all contacts
- Pulled from local storage / Frappe

### Background Service Logs
- Expandable card showing the last entries from the Android background service
- Useful for debugging missed calls or permission issues

<!-- screenshot: Home screen -->

<!-- screenshot: Manual lookup card -->

---

## Incoming Call Overlay (Android)

When a phone call is received, the app shows a native system-level overlay on top of whatever is on screen.

### Known Caller — Contact Dashboard

Displayed when the caller is matched to a **Lead** or **Customer** in Frappe.

| Section | Content |
|---------|---------|
| **Header** | Caller name, type badge (Lead / Customer), Frappe docname |
| **Contact info** | Mobile number, email |
| **Last Note** | Amber banner showing the most recent CRM note (shared across all team members) |
| **Add Note** | Text field + Save button — note saved directly to Frappe |
| **Convert to Opportunity** | One-tap conversion from Lead → Opportunity (only shown for Leads not yet converted) |
| **Create Quotation** | Opens quotation form pre-filled with the contact's details |

<!-- screenshot: Known caller overlay — contact dashboard -->

<!-- screenshot: Overlay — Add Note panel -->

<!-- screenshot: Overlay — Convert to Opportunity -->

### Unknown Caller — New Lead Form

Displayed when the number is **not** in Frappe.

| Field | Detail |
|-------|--------|
| Name | Required |
| Email | Optional |
| Mobile | Pre-filled from the incoming number |
| Note | Optional note attached on creation |

Submitting creates a Lead in Frappe and saves the note. The next call from that number will show as a known contact.

<!-- screenshot: Unknown caller overlay — New Lead form -->

### Shared CRM Sync
- Contact data is cached in a local Room database (Android) with a **6-hour TTL**
- On cache miss or stale cache → network refresh
- If network is down → serves stale cache gracefully
- Notes saved by any team member are fetched from `tabCRM Note` on each lookup, so the whole team sees the same last note

---

## Manual Lookup

Triggered from the Home screen search card instead of an incoming call.

### Known Contact Sheet
- Same contact card as the overlay (name, type badge, docname, phone, email)
- Amber **Last Note** banner if a note exists
- Inline **Add Note** field — shows green success state after saving
- Fully native Flutter bottom sheet (matches the app's design language)

### Unknown Number Sheet
- Grey "Unknown Number" card with "Not in CRM" badge
- **Save as Lead** inline form: name (required), email (optional), phone pre-filled
- Creates a Lead in Frappe and shows a success snackbar

<!-- screenshot: Lookup result — known contact -->

<!-- screenshot: Lookup result — unknown number / save as lead -->

---

## Pipeline — Leads

The **Leads** sub-tab inside the Pipeline screen.

### Lead Card (Active)
- Avatar with initials, display name, mobile number
- Tappable status chip → opens a quick-pick bottom sheet to update status
- Status options: `Lead`, `Contacted`, `Interested`, `Converted`, `Do Not Contact`
- **Convert to Opportunity** button

### Lead Card (Converted)
- Compact slim row — name + green ✓ Converted chip
- No actions available (can't convert again)

### Create New Lead
- Floating action button on the Leads tab
- Form: first name, last name, email, mobile, initial note

### Lead Status Updates
- Changes synced to Frappe immediately

<!-- screenshot: Leads tab — active leads -->

<!-- screenshot: Leads tab — mixed active + converted -->

<!-- screenshot: Create New Lead sheet -->

---

## Pipeline — Opportunities

The **Opportunities** sub-tab inside the Pipeline screen.

### Opportunity Card
- Avatar, party name, stage chip (colour-coded), expected closing date, opportunity amount
- Tappable stage chip → quick-pick sheet to update stage
- Stage options: `Prospecting`, `Qualification`, `Proposal`, `Negotiation`, `Closed Won`, `Closed Lost`
- **Create Quotation** button

### After Lead Conversion
- Newly created opportunity is **optimistically inserted** at the top of the list immediately
- The Opportunities sub-tab is automatically selected
- Full API refresh runs in the background

### Pipeline Summary Header
- Total open opportunities
- Total pipeline value
- Number of opportunities by stage (displayed in the header stat cards)

<!-- screenshot: Opportunities tab -->

<!-- screenshot: Convert to Opportunity sheet -->

<!-- screenshot: Pipeline summary header -->

---

## Quotes & Orders

### Quotations Tab

**Create Quotation** (from an Opportunity card)
| Field | Detail |
|-------|--------|
| To (Recipient) | Amber card showing party name, phone, email — auto-fetched from Frappe |
| Subject | Pre-filled as "Quotation for [Name]" |
| Currency | Dropdown — full ISO 4217 list (LKR, USD, EUR, and 30+ others) |
| Line Items | Add/remove items; item code field has **live autocomplete** — type a letter and the first matching items from Frappe appear with code, description, and unit price auto-filled |
| Terms & Notes | Free-text field |

**Quotation List**
- Shows party name (not the Frappe docname), status chip, total amount, last modified date
- Status colours: Draft (slate), Submitted (indigo), Ordered (green), Expired (amber), Cancelled (red)
- Pull-to-refresh; auto-refreshes when the Quotes tab is tapped

**Quotation Detail Sheet**
- Full line-item breakdown with qty × rate
- Edit valid-till date (date picker)
- Edit terms & notes
- Actions: Save Changes, Submit Quotation, Cancel Quotation (with confirmation dialog)

### Sales Orders Tab
- Shows all sales orders with status and delivery status
- Delivery status: Not Delivered, Partly Delivered, Fully Delivered

### Summary Header
- Total quotes, draft quotes, total pipeline value

<!-- screenshot: Create Quotation sheet — recipient card + item autocomplete -->

<!-- screenshot: Quotations list -->

<!-- screenshot: Quotation detail sheet -->

<!-- screenshot: Sales Orders tab -->

---

## Settings

| Setting | Detail |
|---------|--------|
| **Server URL** | Shows connected Frappe instance; tap to reconnect to a different server |
| **Overlay toggle** | Enable / disable the incoming call overlay globally |
| **Office Hours** | Toggle; set start time and end time — overlay only fires within these hours |
| **Active Days** | Mon–Sun toggles; overlay only fires on selected days |
| **Profile** | Shows logged-in username and role |
| **Sign Out** | Confirmation dialog → clears all credentials and returns to Site Setup |

<!-- screenshot: Settings screen -->

<!-- screenshot: Office hours configuration -->

---

## Backend API

All endpoints live in `nxtgen_crm_mobile/api.py` on the Frappe server.

| Endpoint | Purpose |
|----------|---------|
| `get_caller_details` | Match incoming number against Leads and Customers; returns display name, email, mobile, and most recent CRM note |
| `get_company_defaults` | Fetch default company, currency, and selling price list |
| `create_lead_with_note` | Create a new Lead and optionally attach a note in one call |
| `update_lead` | Update lead status and/or append a note |
| `create_opportunity` | Convert a Lead to an Opportunity; marks Lead as Converted |
| `update_opportunity` | Update stage, amount, closing date, or add a note |
| `add_call_note` | Append a note to any Lead or Opportunity |
| `get_notes` | Fetch all notes for a Lead or Opportunity |
| `get_quotation_defaults` | Fetch currency, price list, party email/phone for the quote form |
| `search_items` | Live item search by code or name — returns code, description, and price |
| `create_quotation` | Create a Quotation with line items, currency, and terms |
| `submit_quotation` | Submit a Draft quotation |
| `cancel_quotation` | Cancel a Draft or Submitted quotation |
| `create_complaint` | Log a complaint against a contact |
| `delete_test_lead` | Dev utility — remove test leads by phone or docname |

---

## Tech Stack

### Mobile App
| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| Platform | Android (primary), iOS |
| Local DB | Room (Android) — leads cached with 6-hour TTL |
| State | `StatefulWidget` + `AutomaticKeepAliveClientMixin` |
| Native overlay | Kotlin — system-level `TYPE_APPLICATION_OVERLAY` window |
| Call detection | `phone_state` package + Android `BroadcastReceiver` (background) |
| Permissions | `permission_handler` — Phone, Notifications, Draw Over Apps |
| Storage | `shared_preferences` — session, settings, office hours |
| Navigation | `IndexedStack` (keeps all tabs alive) + `GlobalKey` cross-tab refresh |

### Backend
| Layer | Technology |
|-------|-----------|
| Framework | Frappe v15 |
| ERP | ERPNext |
| Server | `sfinax.nxtgenerp.com` |
| Auth | Frappe session cookie (username + password) |
| Doctypes used | Lead, Opportunity, Quotation, Sales Order, Customer, Contact, CRM Note, Item, Item Price |

### Design System
- Dark / light adaptive theme via `AdaptiveColors`
- Indigo (`#6366F1`) for leads/pipeline actions
- Amber (`#F59E0B`) for quotes and notes
- Teal (`#14B8A6`) for customers
- Emerald (`#10B981`) for success states
- Glass-morphism nav bar (blur on iOS, solid gradient on Android — BackdropFilter is invisible in Android release APKs)

---

*Last updated: May 2026*
