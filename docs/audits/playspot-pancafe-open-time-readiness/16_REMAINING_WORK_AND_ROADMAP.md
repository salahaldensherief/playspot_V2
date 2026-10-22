# Remaining work and roadmap

1. **P0, BLOCKED:** reconstruct the exact effective schema in a disposable DB. Compare main/review migrations and production function digests. Test pricing snapshot, duplicate/concurrent start/close, generic completion guard, RLS, partial payment, canteen, DST and legacy clients. Only then propose a financial migration.
2. **P0, BLOCKED:** execute a mixed PC/PS 8–20 station scenario with two cashiers, limited role, manual requests, future booking, offline browser, reconnect, lost acknowledgment, shift close and ledger reconciliation. Record database assertions and UI state; no live money/customer data.
3. **P1, DRAFT:** browser-test the station grid in AR/EN at 6, 20 and 40+ stations, keyboard/contrast, loading/stale/retry, realtime updates and audio preference/autoplay/dedupe. Integrate CI once relevant tests pass.
4. **P1, BLOCKED:** settle Open Time with a server quote/final result path and explicit amount-due/amount-collected display; validate max duration and booking buffer in exact schema.
5. **P2, DESIGN:** ask PanCafe for a written integration contract and sandbox. Until verified, use booking-only manual confirmation; never infer physical device or external inventory status.
6. **P2, RELEASE BLOCKED:** signed Android AAB, target SDK/16 KB, personal-account closed test, policy disclosures; dashboard staging/deployment rollback rehearsal. Do not publish or deploy until gates pass.

See [executive decision](01_EXECUTIVE_SUMMARY.md), [test ledger](12_TEST_RESULTS.md), and [risk register](14_SECURITY_AND_RISK_REGISTER.md).
