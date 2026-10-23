# Unverified assumptions and decisions

Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).

## Coverage that prevents claiming Task01 complete

| Unknown / decision | Why current evidence is insufficient | Smallest resolving evidence |
|---|---|---|
| Every meaningful Dashboard contract semantically correct | Lexical register and pg_proc matching do not validate every nested request/response/null/type/role/UI state | Per-call typed contract fixtures and authorized full-stack role matrix; expand dynamic wrappers |
| Current deployed clients/build/configuration | dev, main, PR CI and hosted DB are different states | Record actual artifact hashes/config versions and match exact runtime contracts |
| Whole deployed schema integrity |59 native suites use reduced/stubbed schemas; no full-chain restore | Disposable exact schema/dependency rehearsal with synthetic data and full trigger graph |
| Complete20:00 busy shift |Only constituent races and two probes executed | Composed multi-action scenario plus real operator walkthrough/audio/network recovery |
| Real Auth/Storage/Realtime/FCM behavior |Unit/mocks and catalog reads do not exercise services | Authorized staging accounts/two tenants, real login/refresh/logout/proof links/private URLs/events |
| PS-004 full-stack financial impact |Exact live function in reduced fixture shows inferred collection, missing some production triggers | End-to-end staged paid/partial extension with receipts and shift reconciliation; agree collection meaning |
| P0 cross-tenant/overlap/secret exposure |No invasive production tests or full historical secret scan performed | Isolated adversarial role/tenant/constraint tests and redacted secret-history scan; never production destructive probes |
| Remaining deployed Edge parity |Only announcement source and version inventory deeply compared | Hash/review every deployed Edge source/authorization vs canonical owner repository |
| Windows/browser offline readiness |Source journal/permits and fixtures are not device power-loss evidence | Crash/reopen/key-store/eviction/multi-tab/offline-cold-start tests on supported platforms |
| Vendor reserve guarantee |No official versioned API/vendor environment tested | Authorized docs+real sandbox race/replay/unknown-outcome evidence |
| Lite Bridge promise |Manual confirm currently only changes PlaySpot state | Partner-approved enforceable capacity partition or evidenced external allocation protocol |
| Early-start/no-show/deposit policy |UI controls and existing status names are not a signed operating policy | Partner operational decision with tested server enforcement/audit and measurable experiments |
| Partner trial/commission/pricing |Business hypotheses; fixed15% paths and configurable partial cash may differ | Explicit approved terms+rate provenance, no retroactive financial rewrite |
| Install-free demand |Flutter web/config existence does not prove browser booking or conversion | Landing/deep-link test, browser acceptance and real abandonment reasons before second app |
| Genuine incremental demand |Channel origin does not show whether player would otherwise phone/WhatsApp | Consent-aware customer feedback/cohort comparison; report attribution uncertainty |
| Partner willingness to pay |Free onboarding/registration/co-marketing claims are not paid demand | Explicit offer discussion and eventually actual paid commitment |
| Every historical branch reviewed |Refs/cherry comparison is broader than manual diff inspection | Inspect targeted plus-patch candidates if relevant; do not merge by branch age/name |

The unverified30% no-show figure is not used as market data. No Egyptian benchmark, vendor guarantee, automated refund success, real cashier fraud or commercial demand is inferred. Pilot thresholds in10 are proposed experiments. This package supports a focused remediation/rehearsal decision, not a launch certificate.
