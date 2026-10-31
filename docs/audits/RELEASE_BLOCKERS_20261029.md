# Release candidate progress and gates — 29 October 2026

This is a local checkpoint, not a release acceptance statement. Production and hosted staging were not accessed in this task.

## Verified progress

- Financial stack preserved; new payout regression commit `aa8628f4262f198e79f158399fae20d1b9221c7b` adds refund initiation versus payout creation in both commit orders and payout waiting for actual refund execution. Assertions cover request/payout/settlement counts, net collections, payment totals and commission. It also fixes ineffective SET LOCAL lock_timeout outside a transaction to a session timeout with cleanup. No SQL business change.
- Native PostgreSQL 17.11, loopback 55439: manual refund 35, refund-aware payout 35, custody 17, partial cash 47; all exited 0, total 134. Logs in task outputs/rc-backend-*.log. Synthetic schemas/Auth helpers remain a limitation.
- Mobile checkout Cubit tests: 9 passed. Source checks confirmed guards against repeated confirmation and committed-booking proof attachment failures; status badges already distinguish partial, refunded and pending. No mobile UI rewrite or new mobile business behavior was justified in this scope.
- Dashboard financial-card narrow layout was reproduced and fixed in its own repository. Focused 5 tests and full 1,340 passed/2 skipped; analysis/formatting and release Web build succeeded. Browser control failed to initialize its local kernel; no real browser/Auth acceptance claimed.
- Source comparison: Dashboard checkout sends booking/shift/operation/minor amount plus mutually exclusive discount inputs matching backend source signatures; verifies canonical receipt identifiers and collected amount. Deposit verification sends the five canonical parameters and verifies its receipt. Staff permissions validate branch/target/permission responses. This is source/mocked compatibility only, not the live deployed contract.

## Blocker register

| Severity | Owner | Evidence / impact | Required gate |
| --- | --- | --- | --- |
| Critical | Backend / deployment | Hosted schema/function/default/grant/RLS compatibility has not been independently verified. Eleven manually applied migrations and ledger mismatch remain inherited claims. | Separately authorized read-only staging catalog reconciliation, then isolated exact-schema sequence tests and backup/recovery proof. No ledger repair or hosted SQL now. |
| Critical | Finance | Refund/payout migrations remain unmerged financial branches. Local synthetic success does not establish compatibility with historical payments, deployed Auth, or clients. | Review effective live definitions and accounting invariants; authenticated acceptance across legacy/new clients before integration/rollout. |
| High | Platform finance / clients | Server custody paths are tested synthetically; Dashboard deposit UI uses lounge custody and no complete platform-finance refund/payout E2E was verified. | Authorized platform/lounges workflow acceptance and receipt/ledger/shift reconciliation. |
| High | CI/CD | Dashboard dev pushes are coupled to Vercel Preview by existing integration evidence. No deployment authorization. Mobile workflows build/test without visible hosted mutation, but remote protection/service hooks not independently checked here. | Hold Dashboard push. Confirm exact push side effects and required review gates before any delivery. Never bypass protections. |
| High | QA / browser | Widget layout tests pass; Computer Use failed kernel setup. Hosted Auth and end-to-end journeys not run. | Restore browser tooling; inspect local AR/EN fixture, then separately authorized hosted customer/cashier/owner flows. |
| High | Android release | No android/key.properties in active worktree. Gradle rejects missing release signing unless explicit compile-only debug-signing override. No new release artifact created. | Securely verify existing upload keystore, target SDK in built manifest, build signed artifact, device installation and permissions. Do not substitute keys. |
| High | Store / privacy | In-app account deletion calls delete-account Edge Function; hosted deletion and external deletion web resource unverified. Privacy screens exist; published content and Data safety accuracy unverified. | Owner-approved privacy/retention disclosures, working deletion request web link and real deletion acceptance; Play Console review. |
| Medium | Operations | Offline/native controls and hardware acceptance remain unverified. | Simulated concurrency/security tests plus separately supported adapter/hardware validation before activation. |

## Release source inventory and official policy references

`android/app/build.gradle.kts`: compileSdk 37, targetSdk delegated to Flutter; namespace com.playspot.app, applicationId com.playspot.client. Inspect the actual built manifest before target-API compliance claims. As checked against [official Android target SDK guidance](https://developer.android.com/google/play/requirements/target-sdk), new/update submissions require API 36 from August 31, 2026. [Official account deletion policy](https://support.google.com/googleplay/android-developer/answer/13327111) requires an in-app path and an external deletion request resource for apps with account creation. Existing source alone does not prove compliance. No store details, legal statements or production retention rules were invented.

## Integration and next acceptance

No financial branch merged into dev: absent independent schema compatibility and rollout evidence prevents claiming it safe. Preserve original dirty AGENTS/handoff and all backup refs. A local test-only commit is retained on payout; no force-push, hosted change, publication or deployment occurred. Dashboard's independent layout fix can be consolidated locally, with remote push held at its deployment boundary.

Next: review local finance diff and reproduce exact-schema historical-record behavior; restore local browser tooling to inspect the synthetic financial card; obtain separately authorized staging read-only evidence; verify complete Auth/permissions/collection/refund/payout journeys; verify signing and device acceptance before making a release artifact available for realistic testing.
