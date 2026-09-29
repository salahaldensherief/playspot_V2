# Foundation Contract: Core Schema, Timezone, Permissions & Feature Flags

## Overview
This foundation migration establishes foundational capabilities required by all upcoming PlaySpot backend features:
1. **Lounge Timezone & Operating Hours (`business_date`)**
2. **Expanded Domain Enums (`payment_method`, `category`, `notification_type`)**
3. **Role & Staff Permission Key Registry**
4. **Tenant-Aware Feature Flag Infrastructure (`feature_flags`)**

---

## 1. Lounge Timezone & Business Date

### `public.business_date(p_lounge_id uuid, p_ts timestamptz DEFAULT now())`
Calculates the operational business date for a given lounge, respecting its configured timezone (`lounges.timezone`) and overnight operating hours.

- **Parameters:**
  - `p_lounge_id` (`uuid`, required): Lounge ID.
  - `p_ts` (`timestamptz`, default `now()`): UTC timestamp to evaluate.
- **Returns:** `date` (Operating business date).
- **Behavior:**
  - Converts UTC `p_ts` to local time in `lounges.timezone` (defaults to `'Africa/Cairo'`).
  - If closing time is past midnight (e.g., opens 10:00 AM, closes 03:00 AM) and `p_ts` falls between 00:00 AM and closing time, returns the previous calendar date (`local_date - 1`).
- **Security:**
  - `SECURITY DEFINER`, `search_path = ''`.
  - `REVOKE ALL FROM PUBLIC, anon;`
  - `GRANT EXECUTE TO authenticated, service_role;`

---

## 2. Updated Domain Constraints

| Table | Constraint Name | Column | Allowed Values |
|---|---|---|---|
| `public.bookings` | `bookings_payment_method_check` | `payment_method` | `'cash'`, `'manual_transfer'`, `'online'`, `'card'`, `'wallet'`, `'instapay'`, `'fawry'`, `'vodafone_cash'`, `'points'`, `'free'`, `'package'`, `'other'`, `'visa'`, `'mastercard'`, `'pos'`, `'credit_card'`, `'bank_transfer'` |
| `public.payments` | `payments_payment_method_check` | `payment_method` | *(Same as bookings)* |
| `public.shift_payments` | `shift_payments_payment_method_check` | `payment_method` | *(Same as bookings)* |
| `public.shift_payments` | `shift_payments_category_check` | `category` | `'booking'`, `'canteen'`, `'session'`, `'package_sale'`, `'tournament_entry'`, `'other'`, `'expense'`, `'refund'`, `'deposit'`, `'withdrawal'`, `'general'` |
| `public.notifications` | `notifications_type_check` | `type` | `'booking_confirmed'`, `'booking_cancelled'`, `'booking_reminder'`, `'booking_completed'`, `'points_earned'`, `'points_redeemed'`, `'tier_upgraded'`, `'tier_downgraded'`, `'tournament_registered'`, `'tournament_starting'`, `'tournament_won'`, `'waitlist_promoted'`, `'system'`, `'general'`, `'package'`, `'package_expiring'`, `'winback'`, `'group_invite'`, `'group_update'`, `'tournament_invite'`, `'growth_insight'`, `'price_change'` |

---

## 3. Seeded Permission Keys (`public.app_permissions`)

| Key | Arabic Name | Category | Default Owner | Default Manager | Default Cashier |
|---|---|---|---|---|---|
| `packages.manage` | إدارة الباقات | `packages` | `true` | `true` | `false` |
| `packages.sell` | بيع الباقات | `packages` | `true` | `true` | `true` |
| `pricing.manage` | إدارة التسعير والعروض | `pricing` | `true` | `true` | `false` |
| `growth.view` | عرض تحليلات النمو | `analytics` | `true` | `true` | `false` |
| `crm.view` | عرض قائمة العملاء | `crm` | `true` | `true` | `false` |
| `crm.view_contact` | عرض بيانات الاتصال | `crm` | `true` | `false` | `false` |
| `campaigns.manage` | إدارة الحملات التسويقية | `campaigns` | `true` | `false` | `false` |
| `canteen.combos.manage` | إدارة عروض الكانتين | `canteen` | `true` | `true` | `false` |
| `audit.view` | عرض سجل العمليات | `audit` | `true` | `true` | `false` |
| `groups.manage` | إدارة المجموعات | `groups` | `true` | `true` | `false` |

### Helper Function: `public.has_lounge_access(p_lounge_id uuid, p_min_role text DEFAULT 'staff')`
Checks if the current authenticated user has access to a lounge with at least `p_min_role` ('owner', 'manager', 'cashier', 'staff').

---

## 4. Feature Flags Infrastructure (`public.feature_flags`)

### Table Schema
- `id` (`uuid PRIMARY KEY DEFAULT gen_random_uuid()`)
- `key` (`text NOT NULL`)
- `lounge_id` (`uuid REFERENCES public.lounges(id) ON DELETE CASCADE`, `NULL` for global flags)
- `enabled` (`boolean NOT NULL DEFAULT false`)
- `description` (`text`)
- `created_at` / `updated_at` (`timestamptz NOT NULL DEFAULT now()`)

### Evaluator Function: `public.is_feature_enabled(p_key text, p_lounge_id uuid DEFAULT NULL)`
Evaluates feature status:
1. Checks lounge-specific override first (`WHERE key = p_key AND lounge_id = p_lounge_id`).
2. Falls back to global flag (`WHERE key = p_key AND lounge_id IS NULL`).
3. Returns `false` if not configured.

---

## Rollback Plan & Safety
- **Non-Destructive Guarantee:** No tables, columns, or existing constraints are dropped or altered in a breaking manner.
- **Feature Deactivation:** Features can be instantly toggled on/off at global or lounge level using `public.feature_flags` without code deployment or SQL deletion.
