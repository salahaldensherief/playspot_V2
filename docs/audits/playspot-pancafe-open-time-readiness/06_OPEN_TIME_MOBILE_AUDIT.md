# Mobile Open Time audit

**SOURCE REVIEWED / MOCK TESTED.** The customer app reads existing bookings into `ActiveSessionModel`; it does not presently authorize a public customer Open Time creation path. Cashier/walk-in authority stays on the dashboard/server. Before this change, a missing fixed duration could be inferred from price, yielding a false countdown and expiry/extension affordance. Running Open Time billing could look like a final zero-price receipt.

The changed model retains `is_open_time`, `open_time_started_at` and pricing snapshot. The active screen uses elapsed time, labels Open Time in Arabic/English, suppresses fixed extension and expiry/Live Activity end-time assumptions, and identifies rate/minimum/rounding as policy while final bill is pending. Restart correctness depends on server active-session payload and watcher freshness; the model regression test verifies parsing but an actual reconnect was not run. Server-permitted actions remain decisive.

No customer-side Open Time selector was added because no verified business rule permits it. The app must distinguish authoritative committed canteen charges and estimates in a later integrated billing pass. See [server pricing](08_OPEN_TIME_SERVER_PRICING.md).
