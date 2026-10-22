# Remaining work and roadmap

1. **P0, PARTIALLY VERIFIED / BLOCKED:** a disposable PostgreSQL 17.11 reconstruction now passes pricing snapshot, rounding, maximum duration, concurrent/sequential start, duplicate close, partial collection, canteen, future boundary, RLS and ledger fixtures. It is a minimal reconstructed contract, not an exact production schema snapshot. Compare the complete migration chain and production function digests before proposing or merging a financial migration; DST and legacy-client parity remain open.
2. **P0, BLOCKED:** execute a mixed PC/PS 8–20 station scenario with two cashiers, limited role, manual requests, future booking, offline browser, reconnect, lost acknowledgment, shift close and ledger reconciliation. Record database assertions and UI state; no live money/customer data.
3. **P1, PARTIALLY VERIFIED:** localhost Chromium checks passed for AR/EN at 6, 20 and 40 stations, including stale state, conflict review, alerts and permission-state presentation. Keyboard/contrast, real sound/autoplay/dedupe and multi-cashier offline endurance remain open.
4. **P1, DRAFT / EXACT-SCHEMA BLOCKED:** Mobile now separates unfinalized time, committed canteen charges, amount due and unconfirmed actual collection. Reconstructed fixtures pass maximum duration and future-booking boundary, but final server quote/collection truth still needs exact-schema validation.
5. **P2, DESIGN:** ask PanCafe for a written integration contract and sandbox. Until verified, use booking-only manual confirmation; never infer physical device or external inventory status.
6. **P2, RELEASE BLOCKED:** signed Android AAB, target SDK/16 KB, personal-account closed test, policy disclosures; dashboard staging/deployment rollback rehearsal. Do not publish or deploy until gates pass.

See [executive decision](01_EXECUTIVE_SUMMARY.md), [test ledger](12_TEST_RESULTS.md), and [risk register](14_SECURITY_AND_RISK_REGISTER.md).
