## Summary

Describe what changed and why.

## Scope

- [ ] Mobile UI / state
- [ ] Dashboard UI / state
- [ ] Domain / repository contract
- [ ] Supabase schema / RPC / RLS
- [ ] Payments / pricing
- [ ] Booking lifecycle
- [ ] Notifications / realtime
- [ ] No backend contract changes

## Safety checks

- [ ] I reviewed the repository agent rules before changing code.
- [ ] No service-role key, password, token, or secret was added to source control.
- [ ] User-facing strings use localization.
- [ ] Server-authoritative pricing / permissions / availability rules were not duplicated in the client.
- [ ] New or changed Supabase behavior is represented by a tracked migration.
- [ ] RLS / RPC grants were reviewed when database access changed.
- [ ] Realtime subscriptions and controllers are disposed correctly.

## Verification

- [ ] `flutter analyze --no-fatal-infos`
- [ ] `flutter test`
- [ ] Relevant success path tested
- [ ] Relevant failure / empty / unauthorized path tested
- [ ] Arabic / RTL checked when UI changed
- [ ] English / LTR checked when UI changed

## Database impact

Describe migrations, RPC changes, RLS changes, backfills, rollback considerations, or write **None**.

## Cross-repository impact

Describe whether the companion Mobile/Dashboard repository requires a matching contract change, or write **None**.
