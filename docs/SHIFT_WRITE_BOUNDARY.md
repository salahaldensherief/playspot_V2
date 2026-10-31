# Shift lifecycle writes

Both current clients were searched for direct `shifts` writes. Dashboard reads shifts but opens with `open_lounge_shift`, closes with `blind_close_shift`, and approves with `approve_shift`; no current direct insert/update/delete consumer was found. These live operational functions are SECURITY DEFINER, with actor/scope checks. Membership-only RLS policies nevertheless left table-wide financial/approval writes available to authenticated API users.

Migration `20261010121841_shift_rpc_write_boundary.sql` revokes direct INSERT/UPDATE/DELETE from anon/authenticated. It preserves SELECT and existing policies, service grants and RPC signatures. Synthetic grant tests reject forged approval/cash/cashier/delete attempts, retain reads, and demonstrate owner-executed transitions. Existing close authorization suites cover real operational function source separately. This does not repair blind finance SELECT disclosure.

Before test deployment verify no column-level write grants survive, and check any external consumers not in these repositories. Apply after eligible legacy helper migration, then test current clients and forged requests using real test tokens. Source is tested; full Supabase deployment/behavior is outstanding.

Rollback: capture effective table and column grants before applying. Restore only the previously captured grants in a reviewed migration if an undiscovered legitimate consumer breaks; keep server actor checks. Do not drop policies/tables or change historical shift totals.
