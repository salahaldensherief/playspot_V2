# Initial PGlite attempt results
Native PostgreSQL subsequently passed all59 suites. These initial errors are not relabelled as passes.
| Suite | Exit | First error / limitation |
|---|---|---|
| account_deletion_transaction.test.mjs | 1 | error: role "service_role" does not exist |
| admin_deactivation_consistency.test.mjs | 1 | error: role "service_role" does not exist |
| auth_disable_recovery.test.mjs | 1 | error: role "service_role" does not exist |
| blind_shift_read_authorization.test.mjs | 0 | Completed |
| booking_actor_authorization.test.mjs | 1 | error: extension "btree_gist" is not available |
| booking_completion_balance.test.mjs | 1 | error: role "supabase_auth_admin" does not exist |
| booking_extension_price_integrity.test.mjs | 0 | Completed |
| booking_legacy_cash_ledger.test.mjs | 0 | Completed |
| branch_booking_read_scope.test.mjs | 1 | error: role "supabase_auth_admin" does not exist |
| canonical_lounge_authorization.test.mjs | 1 | error: role "authenticated" does not exist |
| canteen_catalogue_tombstones.test.mjs | 1 | error: role "supabase_auth_admin" does not exist |
| cash_session_start.test.mjs | 1 | error: extension "btree_gist" is not available |
| cashier_conflict_review.test.mjs | 1 | error: extension "btree_gist" is not available |
| cashier_writer_availability.test.mjs | 1 | error: role "service_role" does not exist |
| cashier_writer_release.test.mjs | 1 | error: extension "btree_gist" is not available |
| cashier_writer_renewal.test.mjs | 1 | error: extension "btree_gist" is not available |
| checkout_pricing_and_canteen.test.mjs | 1 | error: role "supabase_auth_admin" does not exist |
| client_table_management_privileges.test.mjs | 0 | Completed |
| customer_booking_timeline.test.mjs | 0 | Completed |
| financial_client_privileges.test.mjs | 1 | error: role "service_role" does not exist |
| future_booking_hold.test.mjs | 1 | error: extension "btree_gist" is not available |
| future_offline_coverage.test.mjs | 1 | error: extension "btree_gist" is not available |
| latest_writer_contracts.test.mjs | 1 | error: extension "btree_gist" is not available |
| legacy_lounge_access_authorization.test.mjs | 1 | error: role "service_role" does not exist |
| live_booking_read_permissions.test.mjs | 0 | Completed |
| live_request_ownership_and_resolution.test.mjs | 0 | Completed |
| live_session_visit_number.test.mjs | 0 | Completed |
| lounge_operating_status.test.mjs | 1 | error: extension "btree_gist" is not available |
| lounge_review_integrity.test.mjs | 0 | Completed |
| lounge_review_summary.test.mjs | 0 | Completed |
| offline_booking_hold_guard.test.mjs | 1 | error: extension "btree_gist" is not available |
| offline_canteen_reconciliation.test.mjs | 1 | error: role "service_role" does not exist |
| offline_cash_reconciliation.test.mjs | 1 | error: role "service_role" does not exist |
| offline_cashier_bootstrap.test.mjs | 1 | error: extension "btree_gist" is not available |
| offline_fixed_session_reconciliation.test.mjs | 1 | error: extension "btree_gist" is not available |
| offline_permit_renewal.test.mjs | 1 | error: extension "btree_gist" is not available |
| onboarding_bootstrap.test.mjs | 0 | Completed |
| onboarding_resource_save.test.mjs | 0 | Completed |
| owner_auth_provisioning.test.mjs | 0 | Completed |
| owner_lounge_contact_fields.test.mjs | 0 | Completed |
| partial_cash_collection.test.mjs | 1 | error: role "service_role" does not exist |
| payout_funds_custody.test.mjs | 1 | error: role "service_role" does not exist |
| platform_revenue_authorization.test.mjs | 0 | Completed |
| points_balance_authorization.test.mjs | 1 | error: role "service_role" does not exist |
| profile_security.test.mjs | 0 | Completed |
| promotion_scope.test.mjs | 1 | error: role "service_role" does not exist |
| shift_direct_write_authorization.test.mjs | 0 | Completed |
| slot_waitlist_view_boundary.test.mjs | 0 | Completed |
| staff_provisioning.test.mjs | 0 | Completed |
| super_admin_security.test.mjs | 1 | error: role "service_role" does not exist |
| terminal_extension_lifecycle.test.mjs | 1 | error: role "supabase_auth_admin" does not exist |
| tournament_bracket_progression.test.mjs | 1 | error: role "anon" does not exist |
| tournament_bronze_playoff.test.mjs | 1 | error: role "anon" does not exist |
| tournament_clock_phases.test.mjs | 1 | error: role "anon" does not exist |
| tournament_match_start_lifecycle.test.mjs | 1 | error: role "anon" does not exist |
| tournament_registration_payments.test.mjs | -1073740791 | error: role "anon" does not exist |
| tournament_reward_delivery.test.mjs | 0 | Completed |
| wallet_concurrency.test.mjs | 1 | Error: Concurrency requires native PostgreSQL |
| wallet_payment_integrity.test.mjs | 0 | Completed |