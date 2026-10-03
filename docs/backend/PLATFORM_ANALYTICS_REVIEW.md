# Platform analytics actor contract — 2026-10-03

Read-only inspection found that hosted `get_revenue_over_time(uuid,text)` recognizes
only `profiles.role='super_admin'`. `get_dashboard_overview()` instead delegates to
`is_super_admin()`, which recognizes the platform registry and legacy role too.
A registry administrator with an owner profile can therefore load the overview
but cannot obtain the same global chart. Client fallback to global tables or
fabricated zero values is prohibited.

`supabase/repairs/platform_revenue_actor_contract.sql` is **review-only**, outside
the automatic migration discovery path. It preserves the signature, JSON keys,
Cairo time grouping, completed payments and ordinary lounge membership scope.
It delegates platform authority to the shared helper and additionally requires
an existing Auth identity and an active, unbanned profile. Anonymous execution is
revoked. Stage it with `active_super_admin_boundary.sql`; neither was applied here.

The fixture verifies owner isolation, registry and legacy administrators, inactive,
banned/deleted identities, unsupported/null periods, Cairo date boundaries and
restricted table/anonymous access. It deliberately uses synthetic records.

Hosted `get_top_lounges_by_revenue()` has no actor check, but its execute grant is
restricted to privileged server roles. It is **not** an authenticated-client leak
in the inspected deployment. The client calls the guarded integer overload with
`limit_count`; its count is completed payment rows, not unique bookings.

Hosted `get_dashboard_overview.total_revenue` sums non-cancelled booking values,
including unpaid bookings. Dashboard now labels it booking value and does not
invent occupancy, commission or session fields absent from this response.
Chart period means aggregation granularity, not a rolling date filter.

Missing KYC/loyalty RPCs, broader offline integration and hosted staging rollout
remain tracked in the existing review documents. Do not infer production readiness
from isolated fixture success. Function privilege guidance was checked against
[Supabase database functions](https://supabase.com/docs/guides/database/functions).
