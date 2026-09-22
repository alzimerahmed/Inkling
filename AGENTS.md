# Inkling — Rules for AI Agents

## Project

Inkling = fork of theachoem/StoryPad (upstream: https://github.com/theachoem/storypad). FOSS privacy-first journal & diary app (timeline journaling, multi-page entries, rich-text writing with 1300+ Google Fonts, photo memories, feelings/moods tracker with 45+ emotions, throwback memories, tags/stars/search, PIN + biometric lock, local backup/export, themes, 20+ languages). Fully independent from upstream (upstream history dropped at fork; no code sync). Distribution: GitHub Releases + F-Droid ONLY.

**License:** GPL-3.0 (inherited from StoryPad) — keep it. GPL requires preserving upstream copyright/attribution in the LICENSE file and source headers. Do NOT strip upstream copyright notices (that would violate the license); project identity/rebranding elsewhere is fine.

**Scope:** Multi-platform Flutter app — Android (primary), iOS, macOS. Linux/web folders exist upstream but are not priority targets. Min focus: Android.

## Tech Stack & Conventions (inherited from upstream — do not fight it)

### Language & Tooling
- **Language**: Dart (SDK ^3.11), Flutter (3.29.0+), null-safe.
- **Build System**: Flutter tooling + `bin/dev` scripts (`bin/dev --community` for Android community build; generates empty Dart-defines fallbacks for RevenueCat/Maps/Google Sign-In).
- **Java**: 21 LTS (for Android build).
- **Code Formatter**: `dart format` (default Dart style). Analyze with `flutter analyze` (flutter_lints 6.x).
- **Codegen**: `build_runner` — copy_with_extension_gen, json_serializable, objectbox_generator, flutter_gen_runner. Run `dart run build_runner build --delete-conflicting-outputs` after model changes.

### UI Framework & Conventions
- **UI System**: Flutter Material (uses-material-design), Material 3 with `dynamic_color`.
- **State Management**: `provider` package, three deliberate levels:
  - Global state: `ProviderScope` (app lifetime)
  - View state: `ChangeNotifierProvider` (page lifetime)
  - Widget state: plain `StatefulWidget`
- **Architecture**: MVVM. Each view = View + ViewContent + ViewModel (+ optional Model). e.g. `EditStoryView` / `EditStoryContent` / `EditStoryViewModel`. Keep business logic in ViewModels; ViewContent is layout-only.
- **Rich text**: flutter_quill (pinned fork of theachoem/flutter-quill) + dart_quill_delta.
- **Localization**: `easy_localization` — all UI text via translation keys in `translations/` (20+ languages). Never hardcode user-visible strings.

### State & Concurrency
- **ViewModels**: `ChangeNotifier` subclasses (`*ViewModel`), provided per-page; dispose properly.
- **Async**: Dart Futures/Streams; heavy work off the UI isolate (`compute`/`Isolate.run` for parsing/backup).

### Database & Storage
- **Database**: ObjectBox (`StoryDbModel` etc., objectbox_generator, schema in `objectbox-model.json`). ObjectBox model changes are the most data-sensitive area — never remove/rename properties destructively; ObjectBox handles added fields automatically but UID changes break stores.
- **Secure storage**: `flutter_secure_storage` for PIN/secrets.
- **Preferences**: `shared_preferences`.
- **Backup/export**: tar-based full backups (attachments included); text/markdown export.

### i18n
- Community translations in `translations/*.json` — all UI text via easy_localization keys, never hardcoded.

## Build / Verify

```bash
bin/dev --community        # run app (Android, community flavor, no-op API keys)
flutter analyze            # static analysis
dart format .              # format
flutter test               # unit + widget tests (test/)
dart run build_runner build --delete-conflicting-outputs   # codegen
```

**Remote-first verification:** full gates on CI, not local. Local tiered: targeted `flutter test test/<file>` while iterating → `flutter analyze` + scoped tests before commit → CI before merge. Full APK builds only for on-device testing or build-system debugging.

**IMPORTANT — small-batch commands:** Flutter toolchain is heavy. One task per invocation; scoped tests > whole-suite runs while iterating. Long builds (pub get, build_runner, first build) → background + poll.

## Gotchas

- **ObjectBox is the data-loss hotspot**: backup/restore and ObjectBox model migrations are the most sensitive area. Always write model changes carefully, keep backups tested, never ship destructive model edits.
- **GPL-3.0 obligations**: keep LICENSE + upstream copyright (theachoem/StoryPad contributors). Fork must stay open-source.
- **Proprietary/service deps**: Firebase (analytics/crashlytics/firestore), Google Sign-In, Google Drive sync, RevenueCat (`purchases_flutter`), Google Maps. The `--community` flavor runs them as no-ops via Dart-defines. Preserve this split; never make community builds require API keys. F-Droid compatibility: no GMS-hard dependencies in the community path.
- **flutter-quill is a pinned git fork** (`theachoem/flutter-quill` @ d01480f) — do not swap for pub.dev version casually; upstream patches live there.
- **Renaming applicationId** (`com.tc.writestory`) to an Inkling identity is a deliberate ADR decision — do NOT rename casually (breaks update path + user data).
- Some path dependencies exist under `packages/` (e.g. `adaptive_dialog`) — keep them vendored and sandboxed.

## Agent Guidelines & Constraints

### Do's
- **Preserve Data Integrity**: never weaken backup/restore; test backup round-trips.
- **Follow MVVM split**: View / ViewContent / ViewModel — no business logic in widgets.
- **Use the three-level state model** (global ProviderScope / view ChangeNotifierProvider / widget StatefulWidget).
- **Offload Heavy Work**: parsing, backup I/O, DB bulk ops off the main isolate.
- **Format with `dart format`**; keep `flutter analyze` clean.
- **Follow Existing Patterns**: naming `*View`, `*Content`, `*ViewModel`, `*DbModel`, `*Repository`.
- **Write tests** under `test/` for business logic, backup/export, and model changes.

### Don'ts
- **NO Blocking the UI isolate**: no synchronous file I/O, heavy regex, or large DB queries on the main isolate.
- **NO Hardcoded Strings**: translation keys for all UI-visible text (20+ languages).
- **NO Unapproved Third-Party Libraries**: avoid heavy deps unless explicitly requested; respect FOSS/F-Droid (community flavor must stay proprietary-free).
- **NO Destructive ObjectBox model changes** without a migration/backup path.

## Agent Guidelines & Workflow (this repo's .devin system)

### Resource Discipline (mandatory, non-trivial tasks)
Before any non-trivial task:
1. Read `docs/toolset.md` intent-map (task type → resources)
2. Invoke every skill + sub-agent in that row
3. Read every rule for that task type (`.devin/rules/`)
4. At task end: `code-reviewer` sub-agent on final diff (non-negotiable)
5. Append learnings via `/ce-compound` if durable lesson

Phase implementations (task completes a docs/plan.md row): follow `.devin/prompt/phase.md`.

Skip all this for single-line edits, pure Q&A, reading files.

### Project-Type Filter (Flutter journal app)
Per `docs/toolset.md` intent-map:
- **Skip web-only:** frontend-designer, css-architect, pwa-engineer, seo-specialist, search-optimization, playwright-design-clone.
- **Keep universal:** code-reviewer, debugger, test-engineer, security-auditor (biometric lock + backups are security-critical), performance-engineer, git-master, migration-specialist, docs-writer, i18n-specialist, build-optimizer, caveman-compressor, pixel-analyst, vibe-coding-auditor, type-safety-engineer, database-engineer (ObjectBox), state-manager (Provider/MVVM).
- **Quality gates:** `flutter analyze`, `flutter test`, `dart format --set-exit-if-changed .` — no browser tooling. Respect FOSS: community flavor must stay key-free (F-Droid compatible).

## Communication Style

Default **caveman-lite** (lightly compressed, readable, technically accurate). `/caveman` skill for full/ultra/wenyan modes.

## Quick Task Flow

Quick tasks: `.devin/prompt/quick.md` (commandments) + `.devin/prompt/rules.md` (scoping, verification, escalation). Phased work: `.devin/prompt/phase.md`.

## Key References

- `docs/toolset.md` — intent map (task type → skills, sub-agents, rules)
- `docs/plan.md` — phased plan + status
- `docs/project.md` — project state/structure
- `docs/tools-log.md` — .devin resources invoked per session
- `docs/CONCEPTS.md` — project vocabulary
- `docs/research.md` — research, ADRs, gotchas, open questions
- `docs/idea.md` — competitive analysis + Feature Gap List
- Upstream docs — https://storypad.me and https://github.com/theachoem/storypad for feature reference (no code sync)
