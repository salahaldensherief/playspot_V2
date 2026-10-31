# Contract: Canteen Combos, Upsell Engine & Inventory Deduplication

## Overview
This contract establishes the authoritative backend standard for canteen operations, combos, dynamic upselling, and inventory accounting across PlaySpot.

---

## 1. Single Source of Truth & Deduplication Policy

- **Canonical Table:** `public.canteen_order_items` is the **single canonical source** for canteen revenue, inventory reporting, and margin analysis.
- **Reporting Rule:** Canteen revenue MUST only be calculated from `canteen_order_items` where `line_kind IN ('item', 'combo_parent')` on orders with `status IN ('delivered', 'completed')`.
- **Addons Separation:** `bookings.addons_price` is strictly a dynamic session ledger balance mirror for checkout collections; it MUST NEVER be summed together with canteen tables to avoid double-counting.
- **Mobile Compatibility:** `canteen_orders.items` JSONB is maintained as an operational mirror for client UI rendering without breaking legacy mobile clients.

---

## 2. Table Schemas

### `public.canteen_combos`
Combo bundles available for sale at a packaged price.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `uuid` | `PRIMARY KEY` | Combo ID |
| `lounge_id` | `uuid` | `NOT NULL REFERENCES lounges(id)` | Lounge ownership |
| `name_ar` | `text` | `NOT NULL` | Arabic title (e.g. كومبو البرجر والكانز) |
| `name_en` | `text` | | English title |
| `price` | `numeric(12,2)`| `NOT NULL CHECK (price >= 0)` | Package bundle price |
| `days_of_week` | `smallint[]`| `0=Sunday ... 6=Saturday` | Operating days (optional) |
| `available_from`| `time` | | Daily time window start |
| `available_to` | `time` | | Daily time window end |
| `is_active` | `boolean` | `DEFAULT true` | Availability toggle |

### `public.canteen_combo_items`
Component breakdown for inventory depletion.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `combo_id` | `uuid` | `REFERENCES canteen_combos(id)` | Parent bundle |
| `extra_id` | `uuid` | `REFERENCES extras(id)` | Component extra item |
| `quantity` | `int` | `NOT NULL CHECK (quantity > 0)` | Units consumed per combo |

### Line Architecture in `public.canteen_order_items`
When a combo is ordered:
1. **Parent Line (`line_kind = 'combo_parent'`):** Holds the combo price, `combo_id`, and ordered quantity. Summed into order financial revenue.
2. **Component Lines (`line_kind = 'combo_component'`):** Holds the component `extra_id`, `combo_line_id` linking to the parent, `quantity`, with `unit_price = 0` and `total_price = 0`. Used strictly for inventory deduction and item volume analytics.

---

## 3. Remote Procedure Calls (RPCs)

### `public.place_canteen_order(...)`
Authoritative ordering endpoint for both single extras and combos with atomic stock depletion.

- **Parameters:**
  - `p_booking_id` (`uuid`, optional): Attached booking session (`NULL` for cashier counter sale).
  - `p_items` (`jsonb`, required): Array of order items:
    ```json
    [
      {"extra_id": "uuid", "quantity": 1},
      {"combo_id": "uuid", "quantity": 2}
    ]
    ```
  - `p_note` (`text`, optional): Kitchen or cashier note.
  - `p_idempotency_key` (`text`, optional): Duplicate submission guard.
- **Server Enforcement:**
  - Item and combo prices are ALWAYS resolved server-side from `extras` and `canteen_combos`.
  - All component inventory is locked with `FOR UPDATE` and decremented atomically.
  - If any component is short on stock, the entire order is aborted with exception code `OUT_OF_STOCK`.
- **Error Codes:**
  - `OUT_OF_STOCK` (`ERRCODE = 'P0001'`):
    ```json
    {
      "unavailable_items": [
        {"id": "uuid", "name": "بيبسي كانز", "available": 0, "requested": 2}
      ]
    }
    ```

### `public.get_canteen_menu(p_lounge_id uuid)`
Returns active extras and combos currently available (filtered by lounge timezone, day of week, time window, and component stock availability).

- **Returns:**
  ```json
  {
    "extras": [...],
    "combos": [
      {
        "id": "uuid",
        "name_ar": "كومبو سناك",
        "name_en": "Snack Combo",
        "price": 75.0,
        "is_available": true,
        "items": [
          {"extra_id": "uuid", "name_ar": "شيبسي", "quantity": 1},
          {"extra_id": "uuid", "name_ar": "بيبسي", "quantity": 1}
        ]
      }
    ]
  }
  ```

### `public.get_upsell_suggestions(p_booking_id uuid)`
Evaluates active `upsell_rules` against session context (elapsed time, time of day) and returns up to 2 targeted suggestions with impression limits.

### `public.record_upsell_event(...)`
Logs interaction events (`'shown'`, `'accepted'`, `'dismissed'`) into `upsell_events`.

---

## 4. Growth & Intelligence Analytical Views

1. `canteen_attach_rate_v`: Percentage of gaming sessions that generated canteen sales.
2. `canteen_aov_v`: Average Canteen Order Value per lounge.
3. `canteen_top_combos_v`: Top performing combo packages by volume and revenue.
4. `canteen_upsell_conversion_v`: Impression and conversion rates for active upsell rules.
5. `canteen_low_stock_alerts_v`: Items with inventory at or below threshold.
