<div align="center">

# Inkling

[![Flutter](https://img.shields.io/badge/Flutter-3.29-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?logo=android&logoColor=white)](https://www.android.com)
[![iOS](https://img.shields.io/badge/iOS-000000?logo=ios&logoColor=white)](https://www.apple.com/ios)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue)](LICENSE)

**Inkling — privacy-first journal & diary app.**

[Features](#features) · [Tech Stack](#tech-stack) · [Project Structure](#project-structure) · [Quick Start](#quick-start) · [Usage](#usage) · [Roadmap](#roadmap) · [License](#license)

</div>

## Features

- Timeline journaling — no folders or tabs, your entries flow by date
- Multi-page entries — for novels, prompts, or daily notes
- Rich-text writing — bold, lists, checkboxes, colors, 1300+ Google Fonts
- Photo memories — multiple photos per page with custom layouts
- Feelings & moods tracker — 45+ emotions with history and calendar views
- Throwback memories — revisit what you wrote on this day in past years
- Tags, stars, and full-text search
- Privacy first — PIN and biometric lock; data stays on your device
- Backup & export — full local backups with attachments; text and markdown export
- Themes & customization — color themes, dark/light mode, fonts, layouts
- Available in 20+ languages

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.29 / Dart 3.11 |
| State management | Provider + ChangeNotifier (MVVM) |
| Local database | ObjectBox |
| Rich text editing | flutter_quill + dart_quill_delta |
| Localization | easy_localization (20+ languages) |
| Secure storage | flutter_secure_storage (PIN/secrets) |
| Codegen | build_runner (copy_with_extension_gen, json_serializable, objectbox_generator) |

## Project Structure

```
lib/
├── core/            # constants, databases, repositories, services, helpers
├── providers/       # global app state (ProviderScope)
├── views/           # feature screens (View + ViewContent + ViewModel per feature)
├── widgets/         # shared UI components
├── firebase_options/
├── gen/             # generated code (flutter_gen)
├── app.dart
├── main.dart
└── objectbox-model.json
```

## Quick Start

Requirements: Java 21 (LTS), Flutter 3.29.0.

```sh
# Run the app (Android, community flavor — proprietary deps run as no-ops)
bin/dev --community

# Static analysis
flutter analyze

# Tests
flutter test
```

The community flavor generates empty Dart-define fallbacks automatically, so no API keys (RevenueCat, Maps, Google Sign-In) are required.

## Usage

- Write entries on the timeline; add photos, feelings, tags, and stars.
- Lock the app with a PIN or biometrics from Settings.
- Back up or export your data from the backup/export section — full backups include attachments.
- Switch themes, fonts, and languages in Settings.

## Roadmap

- [x] Fork from StoryPad; independent history and identity
- [x] Community flavor stays FOSS and key-free (F-Droid compatible)
- [ ] Establish Inkling release pipeline (GitHub Releases + F-Droid)
- [ ] Review and prune proprietary service dependencies
- [ ] Expand test coverage for backup/restore and ObjectBox models
- [ ] Grow community translations beyond the inherited set

## License

Inkling is licensed under the [GNU General Public License v3.0](LICENSE).

Inkling is a fork of [StoryPad](https://github.com/theachoem/storypad) by [theachoem](https://github.com/theachoem) — thanks to theachoem and all StoryPad contributors for the foundation. GPL-3.0 requires that this fork and all modifications remain open-source under the same license.
