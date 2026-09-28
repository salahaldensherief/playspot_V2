# PlaySpot Mobile

Flutter client for the PlaySpot platform. The app covers lounge discovery, room booking and checkout, active sessions, canteen ordering, loyalty and vouchers, notifications, reviews, favorites, profile flows, and tournaments.

## Stack

- Flutter / Dart
- flutter_bloc / Cubit
- GetIt
- GoRouter
- Supabase Auth, Postgres, Storage, Realtime, RPCs
- Firebase Messaging / Crashlytics
- Easy Localization
- ScreenUtil

## Architecture

Features live under `lib/features/<feature>/` and follow a clean feature structure:

```
feature/
  data/
    datasources/
    models/
    repositories/
  domain/
    entities/
    repositories/
    services/
    strategies/
    usecases/
  presentation/
    cubit/
    screens/
    widgets/
```

Core application services, dependency injection, caching, notifications, and shared utilities live under `lib/core`. Shared design-system and routing code lives under `lib/art_core`.

Business rules belong in domain/use-case layers. Cubits orchestrate use cases and widgets render state. Server-authoritative operations such as booking integrity, pricing validation, payments, inventory, loyalty, permissions, and tournament lifecycle rules must be enforced in Postgres/RPCs rather than trusted to client-side calculations.

Project-specific engineering rules are documented in `AGENTS_RULES.md`.

## Configuration

Runtime credentials are not committed. Supply them with `--dart-define`.

Required:

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-publishable-or-anon-key
```

Mobile map configuration may also require:

```bash
GOOGLE_API_KEY_IOS=...
GOOGLE_API_KEY_ANDROID=...
```

Example:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-key \
  --dart-define=GOOGLE_API_KEY_ANDROID=your-android-key \
  --dart-define=GOOGLE_API_KEY_IOS=your-ios-key
```

See `.env.example` for the variable names. The app reads compile-time dart defines; copying values into a local `.env` file alone does not inject them into Flutter builds.

## Local development

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
flutter test
```

Run on a device/emulator with the required dart defines after the quality checks pass.

## Supabase changes

SQL changes are versioned under `supabase/`. Do not run the entire directory against production and do not apply ad-hoc SQL from a client.

The repository SQL history and the deployed Supabase migration ledger have historically drifted, so every database change must be:

1. reviewed as an isolated migration,
2. compared with the live schema/function definition,
3. tested in a safe environment,
4. checked for RLS / grants / SECURITY DEFINER implications,
5. applied deliberately,
6. followed by Supabase security and performance advisor checks.

Never expose `service_role` or other secret server keys in Flutter.

## Branch and PR workflow

- `main`: release/production history.
- `dev`: integration branch.
- Work branches: `feature/*`, `fix/*`, `chore/*`.
- Open a PR instead of pushing feature work directly to `main`.
- Keep migrations, client contract changes, and tests in the same PR when they form one backend contract.
- Do not merge a PR until Flutter CI is green and any required Supabase migration has been reviewed separately.

See `CONTRIBUTING.md` for the full checklist.

## CI

GitHub Actions runs on pull requests and pushes to `dev` / `main` and checks formatting, static analysis, and tests.

## Localization

User-facing copy must use Easy Localization. Arabic and English resources live under `assets/lang/`. UI changes must be safe in both RTL and LTR layouts.
