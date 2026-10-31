# Cash start and explicit collection contract

Baseline: `0b3b49f9d96734c695d7c74a24516312ca2b938e`.

Candidate `20261016211005_cash_session_start_before_collection.sql` replaces two existing functions without replaying history or altering accounting records:

- `start_booking_session(uuid)`: approved cash play may start unpaid/partially paid. Attendance does not mark payment collected. Unverified prepaid methods and unknown unpaid methods remain blocked; refunded bookings cannot restart. Existing venue permissions, open-shift checks, idempotency and grants remain.
- `create_manual_booking_admin(...)`: immediate play invokes session start without automatically calling `complete_booking_payment`. All pricing, booking, item and authorization checks remain. Receiving cash requires its explicit billing command.

Companion Dashboard changes expose Start independently of collection on four surfaces and stop labelling immediate-start requests as paid. Deploy these contracts as a reviewed coordinated change; the SQL has **not** been applied to production or cinematic Demo.

Verification: new native PostgreSQL suite **19 cases passed**, including baseline failure reproduction, unpaid/partial/paid cash, unverified transfers/unknown/null/refunded refusal, permissions, closed shift, terminal state, retries, ACL preservation and immediate manual start without collection. Entire current native set **55 suites, zero failures**. Fixtures use the supported local online-authority path rather than disabling its booking guard.

Six real isolated local Auth/PostgREST checks passed: immediate play without payment, extension increasing debt, canteen increasing debt, completed session retaining its unpaid total, explicit final settlement and duplicate-collection idempotency. EGP50 play + EGP25 extension + EGP30 drinks = EGP105 settled once. No financial data from hosted projects was changed.

Remaining scope: source-only release candidate, pending hosted prerequisite/deployment review; broader pre-existing start-time/room-concurrency and paid-session add-on accounting behavior are not certified by these tests. Synthetic permission/auth helpers in native tests complement the real local RLS/API run; neither proves hosted rollout success.
