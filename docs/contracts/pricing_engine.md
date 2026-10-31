# Contract: Unified Server-Authoritative Pricing Engine

## Overview
This contract establishes the single server-side source of truth for all pricing across the PlaySpot ecosystem. Regular bookings, Open Time sessions, package sales, and client-side pricing quotes MUST consume this engine directly.

---

## 1. Table Schema: `public.pricing_rules`

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `uuid` | `PRIMARY KEY` | Unique rule identifier |
| `lounge_id` | `uuid` | `NOT NULL REFERENCES lounges(id)` | Lounge ownership |
| `room_id` | `uuid` | `REFERENCES rooms(id)` | Room target (`NULL` = lounge-wide) |
| `space_type_id` | `uuid` | `REFERENCES space_types(id)` | Space type target (`NULL` = all types) |
| `name_ar` | `text` | `NOT NULL` | Arabic rule label (e.g. ساعات الذروة المسائية) |
| `name_en` | `text` | | English rule label (e.g. Evening Peak Hours) |
| `rule_type` | `text` | `CHECK IN ('peak', 'off_peak', 'special_day')` | Rule operational classification |
| `days_of_week` | `smallint[]` | `0=Sunday ... 6=Saturday` | Array of active days |
| `start_time` | `time` | `NOT NULL` | Operating window start time |
| `end_time` | `time` | `NOT NULL` | Operating window end time (supports midnight crossing) |
| `valid_from` | `date` | | Optional activation date boundary |
| `valid_to` | `date` | | Optional expiration date boundary |
| `adjustment_type`| `text` | `CHECK IN ('multiplier', 'percent_delta', 'fixed_rate')` | Price modification mechanism |
| `adjustment_value`| `numeric(10,3)` | `NOT NULL` | Value (multiplier factor, percentage, or fixed rate) |
| `applies_to_play_mode` | `text` | `CHECK IN ('single', 'multi')` | Target play mode (`NULL` = both) |
| `priority` | `int` | `DEFAULT 100` | Precedence rank for collision resolution |
| `is_active` | `boolean` | `DEFAULT true` | Rule operational toggle |

---

## 2. Priority & Resolution Mechanics (Per Minute)

1. **Specificity:**
   - Room-specific rule (`room_id IS NOT NULL`) = Weight 3
   - Space-type-specific rule (`space_type_id IS NOT NULL`) = Weight 2
   - Lounge-wide rule (`room_id IS NULL AND space_type_id IS NULL`) = Weight 1
2. **Priority Value:** Higher integer `priority` wins.
3. **Recency:** Most recent `created_at DESC` breaks remaining ties.
4. **No Stacking:** Exactly **one** pricing rule applies to any given minute segment.

---

## 3. Remote Procedure Calls (RPCs)

### `public.quote_booking_price(...)`
Calculates dynamic booking quotes with segment breakdowns.

- **Parameters:**
  - `p_room_id` (`uuid`, required)
  - `p_date` (`date`, required)
  - `p_start` (`time`, required)
  - `p_end` (`time`, required)
  - `p_play_mode` (`text`, default `'single'`)
  - `p_extra_controllers` (`int`, default `0`)
  - `p_coupon_code` (`text`, optional)
- **Response JSON:**
  ```json
  {
    "segments": [
      {
        "from": "16:00:00",
        "to": "18:00:00",
        "minutes": 120,
        "base_rate": 50.00,
        "applied_rule_id": "uuid",
        "rule_type": "peak",
        "rate": 60.00,
        "amount": 120.00
      }
    ],
    "room_subtotal": 120.00,
    "extra_controllers_amount": 0.00,
    "discount_amount": 0.00,
    "total": 120.00,
    "currency": "EGP",
    "has_peak": true,
    "pricing_rule_ids": ["uuid"],
    "pricing_version": 1
  }
  ```
- **Rounding Policy:** Segments are summed accurately; the final total is rounded once using half-up to the nearest integer (`1.00 EGP`).

### `public.upsert_pricing_rule(...)`
Creates or updates a rule with strict overlap protection.

- **Rejection Policy:** Rejects two active rules sharing identical scope, priority, and overlapping time/days.
- **Error Code:** `PRICING_RULE_CONFLICT` (`ERRCODE = 'P0001'`).
- **Audit:** Logs `pricing_rule_created` or `pricing_rule_updated` (`severity = 'warning'`).
- **Owner Notification:** Dispatches `price_change` push notification to lounge owner upon peak rule activation.

### `public.get_room_slots_with_prices(p_room_id uuid, p_date date)`
Set-based query returning hourly slots with availability, price, and peak status.

### `public.get_lounge_price_range(p_lounge_id uuid)`
Returns `{"min_hourly_rate": 40, "max_hourly_rate": 100, "currency": "EGP"}` for card display.

---

## 4. Discount Interaction Precedence
1. **Pricing Rule Rate** applies first.
2. **Package / Membership Credit** applies second.
3. **Promo / Coupon Code** applies third.
4. **Anti-Stacking:** Discounts do not stack. The largest single discount applies.
5. **Controllers:** `extra_controller_price` is exempt from peak/off-peak rules in v1.
