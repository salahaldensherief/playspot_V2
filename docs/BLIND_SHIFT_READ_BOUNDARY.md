# Blind shift read boundary — 10 October 2026

## Problem and correction
The blind close response masked expected cash and difference, but Dashboard immediately fetched the complete shifts row. Direct SELECT, legacy close/report RPCs, current/live shift RPCs, open_lounge_shift's existing-row return and shift audit old_data/new_data exposed the values again. Dashboard also reconstructed masked nulls and described missing differences as matched.

Apply 20261010120058_eligible_legacy_lounge_access.sql and 20261010121841_shift_rpc_write_boundary.sql before 20261010123112_blind_shift_read_boundary.sql. The last migration:
- Uses live eligible lounge access plus shifts_view_blind_cash (or canonical platform authority) for financial reads.
- Exposes get_visible_shifts with bounded pagination, scoped authorization, explicit financials_visible and null masked values.
- Removes direct SELECT of financial columns; retains identity/state/time columns for RLS-scoped reads and Realtime.
- Protects legacy reports/financial closure; cashier closure uses blind_close_shift.
- Masks current/live/open-shift projections and the lounge-details embedded shift.
- Restricts financial audit SELECT and denies the unguarded legacy Z-report endpoint to client roles.

Dashboard must ship with this server migration: all shift row reads use get_visible_shifts; masked values remain nullable; history, summary, handover, financial tabs and KPIs withhold reconciliation rather than render fabricated matches. Authoritative zero and negative expected cash now stay authoritative.

## Verification
PostgreSQL 17.11 isolated synthetic database: baseline rejects-test fails because expected_cash SELECT succeeds; patched suite passes 20 checks. Includes direct read, masked RPC, manager read, cross-lounge denial, excessive pagination, report denial, no partial closure writes, alternate close denial, live/current/open projections, blind close, audit visibility, banned/inactive profiles with unchanged actor identity. Fixture Auth is simulated; these are not real Auth-token or Realtime E2E tests.

Dashboard contract/model/widget tests cover scoped row reads and preserved cashier identity, masked financial fields, authoritative zero/negative balances, masked live overview and mixed KPI suppression.

## Deployment and containment
No production changes. First apply to a complete isolated Supabase environment, inspect pg_get_functiondef and ACLs, run real Auth/Data API/Realtime tests and a complete booking/shift flow. SQL fixtures alone are insufficient.
Use current compatible Dashboard together with the migration. A client version using SELECT * will fail after grants tighten.
Private raw implementations are owner-only; do not grant API roles EXECUTE on _blind_source_* functions.
Verify the Realtime subscription receives identity/status changes without financial fields before approving deployment.

Containment rollback: disable finance/shift screens and revoke client EXECUTE on newly exposed reads if needed; keep financial-column/DML restrictions and eligibility checks. Restore compatible reviewed function definitions from tests/fixtures/blind_shift_read_deployed_definitions.sql only in isolated testing. Reopening historical SELECT/legacy endpoint grants reintroduces disclosure and requires a separate explicit production decision; no automatic rollback restores them.

## Limits
A cashier necessarily knows some operational booking/payment amounts. This change protects server reconciliation totals and financial audit data; it does not claim that every amount visible elsewhere in the product is secret. Full Supabase deployment, real existing-token checks and Realtime verification remain blocked until WSL/Docker is operational.

