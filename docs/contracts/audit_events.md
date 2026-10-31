# Contract: Unified Audit Events & Booking Timeline

## Overview
This specification details the append-only, immutable audit trail infrastructure that powers:
1. **The Executive & Lounge Operations Audit Log** (Dashboard audit view).
2. **The End-to-End Booking Timeline** (for lounge staff and customers).
3. **Automated Change Detection & Sensitive State Logging** via triggers.

---

## 1. Data Models

### `public.event_catalog`
Reference catalog mapping event codes to localization keys, titles, and default severity.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `code` | `text` | `PRIMARY KEY` | Standard event code (e.g. `booking_created`, `shift_opened`) |
| `entity_type` | `text` | `NOT NULL` | Related entity (`booking`, `payment`, `shift`, etc.) |
| `default_severity` | `text` | `CHECK IN ('info', 'warning', 'critical')` | Default severity level |
| `label_key` | `text` | `NOT NULL` | Localization key for client translation |
| `title_ar` | `text` | `NOT NULL` | Default Arabic display label |
| `title_en` | `text` | `NOT NULL` | Default English display label |
| `description` | `text` | | Human-readable explanation of event trigger |

### `public.audit_events`
Append-only log table. RLS-protected, strictly read-only for API clients, no `UPDATE` or `DELETE` permitted.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `uuid` | `PRIMARY KEY DEFAULT gen_random_uuid()` | Event ID |
| `lounge_id` | `uuid` | `REFERENCES lounges(id) ON DELETE CASCADE` | Associated lounge |
| `occurred_at` | `timestamptz` | `NOT NULL DEFAULT now()` | Exact moment event occurred |
| `entity_type` | `text` | `NOT NULL` | Entity type |
| `entity_id` | `text` | `NOT NULL` | Target entity primary key |
| `booking_id` | `uuid` | `REFERENCES bookings(id) ON DELETE SET NULL` | Linked booking (if applicable) |
| `actor_user_id` | `uuid` | | User who executed or triggered the operation |
| `severity` | `text` | `CHECK IN ('info', 'warning', 'critical')` | Severity level |
| `event_code` | `text` | `REFERENCES event_catalog(code)` | Event code |
| `payload` | `jsonb` | `NOT NULL DEFAULT '{}'` | Sanitized event parameters |

---

## 2. Remote Procedure Calls (RPCs)

### `public.get_booking_timeline_for_customer(p_booking_id uuid)`
Returns the chronological timeline of a customer's booking. **Customer-safe only** (strips staff identities and internal administrative notes).

- **Caller:** Authenticated customer who owns `booking.user_id` or `service_role`.
- **Parameters:**
  - `p_booking_id` (`uuid`, required): Target booking ID.
- **Returns:** Table of records:
  - `id` (`text`): Event ID.
  - `event_code` (`text`): Action code (e.g. `booking_created`, `booking_approved`, `booking_checked_in`, `booking_extension_approved`, `booking_completed`, `booking_cancelled`).
  - `title_ar` (`text`): Arabic title.
  - `title_en` (`text`): English title.
  - `occurred_at` (`timestamptz`): Real event timestamp.
  - `payload` (`jsonb`): Context metadata (e.g. `total_price`, `duration_hours`).
- **Error Codes:**
  - `42501`: Unauthorized / Access denied.
  - `P0002`: Booking not found.

### `public.get_booking_timeline(p_booking_id uuid)`
Staff and administration timeline view. Merges live `audit_events` with historical records from `audit_timeline_legacy_v`.

- **Caller:** Super Admin, Lounge Owner/Manager, or Cashier of the lounge.
- **Parameters:** `p_booking_id` (`uuid`).
- **Returns:**
  - `event_code` (`text`)
  - `occurred_at` (`timestamptz`)
  - `actor_name` (`text`): Staff full name (phone numbers are strictly excluded).
  - `summary_payload` (`jsonb`)

### `public.get_audit_timeline(...)`
High-volume query interface for the Dashboard Audit screen with keyset pagination.

- **Parameters:**
  - `p_lounge_id` (`uuid`, required)
  - `p_entity_type` (`text`, optional)
  - `p_entity_id` (`text`, optional)
  - `p_actor` (`uuid`, optional)
  - `p_from` (`timestamptz`, optional)
  - `p_to` (`timestamptz`, optional)
  - `p_severity` (`text`, optional)
  - `p_cursor_at` (`timestamptz`, optional)
  - `p_cursor_id` (`uuid`, optional)
  - `p_limit` (`int`, default 50, max 100)
- **Security:** Requires `audit.view` permission or `super_admin`.

---

## 3. Immutability & Security Guarantees
1. **Trigger Enforcement:** Any `UPDATE` or `DELETE` statement executed on `public.audit_events` raises SQL exception `42501` and aborts the transaction.
2. **PII & Token Scrubbing:** `fcm_token` is automatically stripped from audit payloads. Full `receipt_url` strings are sanitized to boolean presence (`"receipt_url_present": true`).
3. **No Retroactive Drift:** Event timestamps reflect the exact `now()` execution moment (`occurred_at`), preventing timeline inversion bugs caused by using scheduled `start_time` as creation time.
