# Contributing to Inkling

Inkling is a FOSS (GPL-3.0) fork of [StoryPad](https://github.com/theachoem/storypad). PRs welcome — please read this first.

## Setup

```bash
git clone https://github.com/alzimerahmed/Inkling.git
cd Inkling
bin/dev --community   # run the community flavor (no API keys needed)
```

Requirements: Flutter 3.29+ (see `.tool-versions`), Java 21 LTS.

## Before opening a PR

1. **Format & analyze:**
   ```bash
   dart format .
   flutter analyze
   ```
2. **Run tests** (scoped while iterating, full suite before the PR):
   ```bash
   flutter test                                  # whole suite
   flutter test test/core/repositories           # scoped, while iterating
   ```
3. **Codegen after model changes** — if you touched anything under `lib/core/databases/models/`:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
   Also update the schema snapshot in `test/core/databases/objectbox_model_guard_test.dart` **only if** you deliberately added a property/entity (never remove lines — see that file's docs).
4. **Translations:** never hardcode user-visible strings. Add keys to `translations/en.json` and use `tr('key')`. Do not hand-edit other language files — run `bin/localize` instead. `test/unused_translations_test.dart` will catch drift.

## Non-negotiables

- **Community flavor purity** — `lib/main_community.dart` must stay key-free and proprietary-SDK-free (F-Droid requirement). New deps must be FOSS-friendly.
- **ObjectBox safety** — never remove/rename DB properties destructively; added fields only. Backup/restore must always round-trip (`test/core/repositories/backup_round_trip_test.dart` covers the payload format).
- **GPL-3.0** — keep LICENSE and upstream attribution intact.
- **flutter-quill is a pinned fork** (`theachoem/flutter-quill` @ `d01480f`) — don't swap for the pub.dev version.
- **applicationId** (`com.tc.writestory`) is not to be renamed casually (breaks update path + user data).

## Architecture conventions

- MVVM: each screen is `*View` / `*Content` / `*ViewModel`. Business logic in ViewModels, never in widgets.
- State: global `ProviderScope` → per-view `ChangeNotifierProvider` → widget-local `StatefulWidget`. Don't introduce new state libraries.
- Heavy work (backup I/O, parsing, media) stays off the UI isolate.
- Naming: `*View`, `*Content`, `*ViewModel`, `*DbModel`, `*Service`, `*Storage`.

## Commits

Conventional Commits: `type(scope): description` (e.g. `feat(stats): add writing streaks`).

## CI

GitHub Actions runs on every push/PR: format check → `flutter analyze` → `flutter test` → community APK build. A PR must be green before merge.
