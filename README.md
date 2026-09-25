# Inkling — a private journal that lives on your device

<div align="center">

[![Platform](https://img.shields.io/badge/Android-3DDC84?logo=android&logoColor=white)](https://www.android.com)
[![iOS](https://img.shields.io/badge/iOS-000000?logo=ios&logoColor=white)](https://www.apple.com/ios)
[![Flutter](https://img.shields.io/badge/Flutter-3.29-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Material 3](https://img.shields.io/badge/Material%203-757575?logo=material-design&logoColor=white)](https://m3.material.io)
[![License](https://img.shields.io/badge/GPL--3.0-blue)](LICENSE)

*A free, open-source journal & diary for Android, iOS, macOS, and Linux. Your entries stay on your device — PIN-locked, backed up locally, and synced end-to-end encrypted to a server you own, or nowhere at all.*

[Download](#quick-start) • [Features](#features) • [Tech Stack](#tech-stack) • [Building](#quick-start) • [Roadmap](#roadmap)

</div>

---

## Features

| | |
|---|---|
| **Timeline journaling** | Entries flow by date — no folders, no tabs, no setup |
| **Multi-page entries** | One entry can hold many pages — novels, prompts, or daily notes |
| **Rich-text editor** | Bold, lists, checkboxes, colors, undo/redo, 1300+ Google Fonts |
| **Photo memories** | Multiple photos per page with custom layouts |
| **Feelings tracker** | 45+ emotions with history and calendar views |
| **Habits** | Writing streaks, daily word-count goals, journaling prompts |
| **Lock** | PIN and biometric unlock — nobody reads your journal but you |
| **Capture anywhere** | Home-screen widget, quick actions, and standalone voice notes |
| **On this day** | Resurface what you wrote one or more years ago today |
| **Search** | Full-text search with match highlighting and filter presets |
| **Backup & export** | Local backups with attachments, auto-backup on a schedule, PDF/text/markdown export |
| **E2E-encrypted sync** | Optional sync to your own WebDAV/Nextcloud — AES-256-GCM encrypted on-device, the server sees only ciphertext |
| **Import** | Bring your history from Day One, Daylio, Google Keep, and Evernote |
| **Yours, fully** | Color themes, dark mode, dynamic color, custom app icons, 20+ languages |

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.29 / Dart 3.11 |
| State management | Provider + ChangeNotifier (MVVM) |
| Local database | ObjectBox |
| Rich text | flutter_quill + dart_quill_delta |
| Sync encryption | cryptography (AES-256-GCM, PBKDF2) over WebDAV |
| Localization | easy_localization (20+ languages) |
| Secure storage | flutter_secure_storage |
| Codegen | build_runner (copy_with_extension_gen, json_serializable, objectbox_generator, flutter_gen) |

## Project Structure

```
lib/
├── core/            # constants, databases, repositories, services, helpers
├── providers/       # global app state (ProviderScope)
├── views/           # feature screens (View + ViewContent + ViewModel)
├── widgets/         # shared UI components
├── gen/             # generated code (flutter_gen)
├── main.dart
└── objectbox-model.json
```

---

## Quick Start

Requirements: Flutter 3.29+, Java 21.

```sh
# Run on Android (community flavor — no API keys needed)
bin/dev --community

# Analyze & test
flutter analyze
flutter test
```

The community flavor substitutes empty Dart-define fallbacks for proprietary services (RevenueCat, Maps, Google Sign-In), so it builds and runs key-free — suitable for F-Droid.

## Usage

Write on the timeline. Long-press or use the FAB for prompts, voice notes, and quick actions. Enable the home-screen widget for one-tap capture. Turn on auto-backup in Settings for scheduled local archives, or configure E2E sync to push encrypted backups to your own WebDAV server. Export any entry as PDF, text, or markdown.

## Roadmap

- [x] Forked from StoryPad — independent history and identity
- [x] Community flavor is FOSS and key-free (F-Droid compatible)
- [x] Streaks, writing goals, and daily journaling prompts
- [x] Home-screen widget and quick capture
- [x] Scheduled local auto-backup
- [x] Import from Day One, Daylio, Google Keep, Evernote
- [x] PDF export and search highlighting
- [x] Weather auto-attach and standalone voice notes
- [x] E2E-encrypted sync to self-hosted WebDAV/Nextcloud
- [x] macOS and Linux desktop support
- [ ] Inkling release pipeline (GitHub Releases + F-Droid)
- [ ] Optional on-device AI features (community-consensus gated)

## License

Inkling is licensed under [GPL-3.0](LICENSE).

Inkling is a fork of [StoryPad](https://github.com/theachoem/storypad) by [theachoem](https://github.com/theachoem) — thanks to theachoem and all StoryPad contributors for the foundation. GPL-3.0 requires this fork and all modifications to remain open-source under the same license.
