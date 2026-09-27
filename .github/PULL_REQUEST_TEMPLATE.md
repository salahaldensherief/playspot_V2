## What changed

Describe the behavior/contract changed by this PR.

## Why

Explain the problem this solves.

## Validation

- [ ] `dart format --output=none --set-exit-if-changed lib test`
- [ ] `flutter analyze --no-fatal-infos`
- [ ] `flutter test`
- [ ] UI checked in Arabic and English when relevant
- [ ] No secrets or production credentials added

## Supabase / backend impact

- [ ] No database change
- [ ] Includes a reviewed migration
- [ ] RLS / grants / SECURITY DEFINER reviewed
- [ ] Migration must deploy before client changes

Migration / RPC notes:

## Rollout / risk

Call out compatibility requirements, order-of-deployment constraints, or rollback concerns.
