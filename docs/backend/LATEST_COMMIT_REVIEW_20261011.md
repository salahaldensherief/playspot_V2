# Latest mobile dev commit review — 2026-10-11

Reviewed `f88b369`, `01618ee`, `b0d7754`, and `9486bd4` after merging the current dev into this branch. Changes follow AGENTS.md: fix the owning server contract, preserve client payloads, use canonical authorization, and append migrations instead of rewriting deployed history.

## Confirmed defects and repairs

- `LoungeDetailPanel` was deleted although two lounge widgets still imported it. Restore it with shared theme colors and theme typography, localized titles, and separate expanded/collapsible presentation helpers. Existing lounge visual tests exercise its consumers.
- Payout RPC replacements treated electronic payments as platform-held money and omitted venue-held commission debt. Restore explicit reviewed custody and immutable settlement snapshots. Unknown custody blocks settlement; no method-name inference.
- Session/payment completion replacements could manufacture a paid state or overwrite existing collections. Restore ledger-derived balances and remaining-only canonical cash collection. Unsupported mixed electronic installments require reconciliation instead of overwriting a summary.
- Booking search replacements regressed to single profile-lounge scope. Keep the latest seven-argument RPC and its search/date/payment filters, while using canonical branch permissions, eligible actors, stable ordering, and bounded pagination. Drop the obsolete four-argument overload.
- Voucher lookup permitted foreign-customer access through a profile role/lounge shortcut. Default lookup to the actor; require an explicit authorized customer with a booking in a checkout-authorized branch for foreign lookup. Custom discounts reject non-finite/negative/non-cent amounts and unvalidated voucher codes.
- Expired permits, missing heartbeats, and closed shifts allowed implicit cashier generation retirement. Require explicit drained writer release; keep generation and queued replay coverage intact. Online availability requires live heartbeat, matching unexpired permit, eligible identity, and current authority. Heartbeat refresh cannot change online/offline mode outside bootstrap.
- Blind shift close automatically released the writer and inverted the bootstrap lock order. Acquire the lounge lock first, retain blind financial masking, validate counted money, and leave writer release to its explicit protocol.
- Preserve the future-booking coverage capability overwritten by the latest operating-status RPC. Lounge deletion and tournament start reject inactive actors and nullable authorization results.

## Verification and deployment boundary

The corrective migration is `20261011133001_latest_commit_contract_hardening.sql`, after the latest existing migration. It deliberately reinstalls function definitions whose earlier reviewed contracts were replaced; it does not recreate the custody tables or rewrite earlier migration files.

Native PostgreSQL regression suites install these final replacement bodies for payouts, completion, branch/voucher/discount scope, writer lifecycle, and blind closure. The local Supabase schema restore and forward migration chain compiled successfully with copied schema constraints, RLS, triggers, and function grants. The outbound notification webhook was removed only in the local fixture before synthetic writes. Hosted customer data was not copied and hosted writes were not performed.

Before production rollout, reconcile the hosted migration ledger: pending earlier custody, completion, read-scope, future-coverage, and remaining-cash migrations are prerequisites despite their timestamps preceding migrations another actor has already deployed. Apply reviewed pending prerequisites and then this corrective migration in an explicit rollout; a successful Git dev merge does not apply hosted SQL.

Local schema compilation and isolated regressions do not establish full production Auth/Realtime/Storage, push delivery, device behavior, or store-release readiness. Corrections to mistaken custody classifications and mixed electronic receipt allocation remain separate workflows; do not fabricate financial revisions to bypass those limits.

Local results: full Flutter suite passed (492 tests, one optional local-network E2E skipped); analyzer completed with 105 pre-existing informational findings and no warnings/errors. All 46 PostgreSQL fixture suites passed; the subsequently extended branch/discount suite (8 cases) and blind-close suite (21 cases) also passed. The six writer lifecycle cases passed against the final replacement definition, including the mode-change bootstrap guard. Formatting was checked across lib/test; unrelated pre-existing formatter debt is reported separately, and changed Dart files are formatted.
