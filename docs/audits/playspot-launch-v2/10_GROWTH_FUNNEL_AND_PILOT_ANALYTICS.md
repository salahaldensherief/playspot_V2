# Growth funnel and pilot analytics

Audit date: 21 October 2026 (Africa/Cairo). Scope: Mobile/backend dev `ca455197568f618285b4f52e1b25bfa52c892eb2`; Dashboard dev `a3b9c4bf50fa2b07c6318475a75dbfac2cd5b6c0`.

Evidence levels: source inspection, hosted **read-only catalog** inspection, isolated synthetic PostgreSQL execution, Flutter unit/widget execution. No live business workflow was executed. `VERIFIED` refers only to a named executed check, never whole-product readiness. Task 01 coverage remains **partial**: live Auth/Storage/Realtime workflows, full-schema combined peak-hour execution, operator usability and exhaustive semantic contract verification remain open. See [12](12_TEST_EVIDENCE.md) and [15](15_UNVERIFIED_ASSUMPTIONS_AND_DECISIONS.md).

## Existing journey and friction

Source-traced authenticated return-user path: (1) home/search venue list, (2) lounge/room selection, (3) booking date/start/duration/play setup and hold, (4) checkout quote/payment selection, (5) submit request, (6) request-success dialog -> My Bookings, (7) receive subsequent venue confirmation, then (8) attend and operator starts service. These are screens/actions, not measured tap counts: date/slot selection, optional extras/voucher/proof add more taps. Guest booking and checkout routes are protected by AppRouter and may insert signin/signup/profile/OTP steps. Exact first-time account steps vary by provider/session/configuration and were not exercised live. Do not present this count as a timed UX test.

Checkout success copy says booking requested/pending review, which is appropriate. Up-to-date availability, clear price and reliable confirmation are value hypotheses to test against phone/WhatsApp. Operator response delay and installation/account friction remain unmeasured. No group booking/loyalty expansion is justified by these hypotheses alone.

DeepLinkService currently captures referral-code aliases into preferences. Flutter web target and Firebase web options exist, and this audit successfully compiled the current Mobile web release. Install-free booking is not established by compilation. Checkout imports dart:io File and provider/storage/location behavior requires browser acceptance. First perform a sandbox browser booking acceptance check on the existing Flutter build; prefer reusing it if successful. Initial acquisition experiment: venue-specific lightweight landing/deep-link with clear pricing/request promise, optional app open and an explicit phone/WhatsApp fallback when no install-free path is proven. Measure install friction before building another consumer app. Reuse existing Flutter journey if real browser testing supports it; do not automatically create a second application.

## Event semantics and minimal scorecard

| Metric / event | Exact proposed definition | Source / deduplication |
|---|---|---|
| partner_contacted/interested/approved | Recorded outreach stage with timestamp and responsible founder; approval means eligibility accepted, not operational activation | Restricted partner tracker; append stage history |
| partner_activated | Approved venue with chosen mode, verified resource authority, trained operator and successful readiness rehearsal | Server/admin approved state + activation revision |
| qr_displayed / co-marketing action | Timestamped evidence of real placement/post/customer explanation; distinguish claimed vs observed | Partner tracker evidence/reviewer; avoid customer images without consent |
| player_link_opened | Consent-appropriate landing visit associated with signed/nonsecret venue campaign id | Deduplicate request/session appropriately; no claim this is a unique person |
| signup/continued | Successful account registration or eligible existing/guest continuation | Auth/server event; do not infer attended customer |
| booking_request_created | Committed canonical booking/request with origin campaign, actor and created_at | Server transaction; unique request id |
| booking_confirmed | Committed accepted status with native capacity/external allocation guarantee | Server transition/event version; never client click alone |
| attendance | Operator-authorized actual check-in/session-start event consistent with booking; record exceptions/reversal | Server event unique(booking_id,outcome,version) |
| completed booking | A genuine attended session reaches authorized completed service; exclude cancelled/rejected/no-show/unattended administrative status changes | Derive from trusted start+completion evidence; audit reversals; payment settlement reported separately |
| repeat reservation | Same pseudonymous actor completes another attended booking after first; also report requested/confirmed repeat separately | Stable scoped user identity, defined30day observation window, exclude merged/test accounts |
| request->confirm | Accepted unique requests / eligible submitted unique requests, segmented by venue/mode/age | Explicit denominator; unresolved/pending shown separately |
| confirm->attend | Attended / confirmed with start time plus grace elapsed | Exclude not-yet-due bookings from denominator |
| support hours/partner | Actual logged support minutes / active partner-week; include setup separately | Founder support log, tagged incident/category |
| integrity incidents | Overlap, wrong/duplicate collection, lost request, unauthorized change, false confirmation; severity and affected services | Incident register + server event ids; zero observed is not proof of absence |
| willingness to pay | Recorded explicit terms discussion/accepted paid commitment at a stated offer | Separate survey intent from actual payment |
| marketplace-originated demand | Booking attributed to platform discovery without venue campaign claim in a declared lookback | Server-preserved origin provenance; unknown stays unknown |

Keep lounge-referred, marketplace-discovered, returning and customer-new-to-venue concepts separate. Origin does not prove incremental demand: ask a brief optional post-session question and compare within venue/cluster/time windows. Historical identity coverage and existing WhatsApp bookings limit inference. Never claim causality from campaign codes alone.

Client events may describe view/click behavior but cannot mint completed-booking metrics. Implement authoritative transition events and immutable origin at request creation; sanitize campaign input, bound retention and maintain consent/version. Avoid raw phone/IP in analytics where pseudonymous identity suffices. Financial records retain their separate legal/operational retention rules.

## Experimental decision criteria — proposed, not industry benchmarks

Wave1 start: no unresolved pilot-blocking security/booking/financial issue in enabled scope; exact deployed contract parity; completed operator rehearsal, named backup operator and reliable request handling. Wave2: after at least2weeks of due-booking data and several actual attended sessions per active partner, no unresolved integrity incidents, confirmation SLA adherence and support load within founder capacity. Proposed review targets: >=90% requests answered within the partner-agreed SLA, >=80% confirmed-due bookings attended, and <=2 support hours/active partner/week after setup. These are experiments to revise, not measured results or Egyptian benchmarks.

Wave3: repeat-use evidence across clustered venues, sustainable support/economics and explicit willingness-to-pay conversations with active partners. Report numerator/denominator and uncertainty, not just percentages. Pause expansion on integrity incidents until explained/fixed. Free-term extension: evidenced cooperation+completed use+support economics and a planned commercial review. First Full Bridge: named demand plus authorized documented operation and safe guarantee. Production Local: device recovery/authority/reconciliation gates from07. Marketing preparation runs in parallel with fixing blockers; avoid forcing downloads.
