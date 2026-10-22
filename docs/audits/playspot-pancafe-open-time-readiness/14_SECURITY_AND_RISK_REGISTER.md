# Security and risk register

| Risk | Severity / evidence | Current control / next gate |
| --- | --- | --- |
| Generic booking completion bypasses canonical close | High, production catalog/source reviewed | Dashboard scheduler mutation removed; 13 focused tests prove alert-only scheduling and authorized canonical close remains reachable. Server transition guard still requires exact-schema staging and older-client review. |
| Historical Open Time close reads mutable settings and marks paid | High, old migration source; not observed in production catalog | Reconstructed PostgreSQL fixtures pass snapshot, rounding, maximum, canteen, partial and duplicate-close cases. Do not invoke legacy path until exact effective schema and production function digests are matched. |
| External reservation claimed without vendor confirmation | High, no documented PanCafe API verified | UI authority notice, manual confirmation, explicit bridge provenance |
| Physical PC/PS control implied by room availability | High, no real agent/hardware | Do not expose success states; separate room booking from device connectivity |
| Offline cash and concurrent writer conflict | High, no endurance pilot this task | Disposable two-cashier/offline fixture and lease/replay audit |
| Shift, canteen and ledger totals diverge | High, reconstructed schema passed 97 finance/RLS checks but exact schema is unavailable | Row-level exact-schema finance reconciliation before pilot |
| Browser alert duplication/autoplay | Medium, one shared sound observed | Preference/permission, dedupe and distinct tone tests pending |
| Android signing/Play compliance | Release blocker, no signed artifact verified | Signed AAB and Play Console checklist |

No credentials are included. Production queries were read-only. Risks are unresolved unless an evidence level explicitly says otherwise.
