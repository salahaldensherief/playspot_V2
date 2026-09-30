# Isolated wallet integrity tests

Requires Node.js. In the backend checkout:

    npm ci --prefix supabase/tests/runtime
    node supabase/tests/wallet_payment_integrity.test.mjs

Or set PLAYSPOT_TEST_RUNTIME to a separate directory with the exact pinned PGlite
package. No remote URL or credentials are accepted. Runner creates an in-memory
PostgreSQL instance and closes it after the test. It loads the phase 7 wallet tables,
new correction SQL and a synthetic minimal fixture. It does not run on Supabase.

Auth/capability helpers are fixture stand-ins; production triggers and all policies
are not copied. Forty-six sequential assertions are not multi-connection concurrency
proof. Test full schema under PostgreSQL 17 in isolated staging before rollout.
The prior test that allowed customer-funded arbitrary topup is intentionally not a
release criterion; the new suite verifies rejection of that insecure flow instead.
