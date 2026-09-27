# Contributing

## Branches

- `main` is the release branch.
- `dev` is the integration branch.
- Start normal work from the current integration baseline.
- Use `feature/<name>`, `fix/<name>`, or `chore/<name>`.
- Do not push feature work directly to `main`.

During the current hardening effort, some draft PRs intentionally target `chore/platform-hardening-phase-1`. After that baseline is integrated, new work should branch from `dev` again.

## Before opening a PR

Run:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
flutter test
```

Also verify:

- no credentials or secret keys were added,
- user-facing strings are localized,
- Cubits contain orchestration rather than parsing/business calculations,
- privileged operations remain server-authoritative,
- new client-accessed tables/functions have correct RLS/grants,
- migrations are focused and safe to apply independently,
- tests cover changed use cases/Cubits when practical.

## Database changes

Do not assume historical SQL files equal deployed production state. Inspect the live object first, then create a forward-only migration for the required delta.

For SECURITY DEFINER functions:

- set a safe search_path,
- authenticate and authorize inside the function,
- revoke broad PUBLIC/anon execution unless intentionally public,
- grant only the roles that need execution.

Never commit `service_role`, database passwords, JWT signing secrets, OAuth secrets, or private API keys.

## Pull requests

Keep each PR focused on one contract or concern. Include:

- what changed,
- why,
- user/operator impact,
- database migration impact,
- test/CI result,
- rollout notes when a migration must land before client code.

Prefer squash merging focused work branches. Do not delete long-lived branches as part of an unrelated PR.
