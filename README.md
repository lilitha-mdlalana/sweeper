# Sweep

Flutter app for fast decluttering of your phone's camera roll. Swipe through photos and videos, queue up what you want gone, and confirm before anything is deleted.

## Features

- **Swipe review** — card-based swiping through your gallery (keep / delete gestures) via `photo_manager`.
- **Video cleaner** — full-screen vertical pager for videos with playback, gesture-based decisions, and prev/current/next controller caching for smooth scrubbing.
- **Deletion queue** — decisions are staged, not applied immediately. Review the queue, undo individual picks (with haptic feedback), then confirm a batch delete.
- **Settings & privacy** — permission handling (photo library access) with a dedicated privacy explainer screen.

## Architecture

Feature-first structure under `lib/features/`, each split into `domain/` (state, models) and `presentation/` (widgets, Riverpod providers):

```
lib/
├── core/
│   ├── navigation/    # AppShell — bottom nav (Home / Review / Settings)
│   ├── theme/         # colors, text styles, ThemeData
│   └── utils/         # shared helpers (e.g. byte formatting)
├── features/
│   ├── gallery/       # media listing, swipe cards, sort order
│   ├── deletion/      # deletion queue, confirm dialog, review screen
│   ├── video_cleaner/ # video pager, controller manager, end screen
│   └── settings/      # app settings, permissions, privacy
└── main.dart
```

State management: [Riverpod](https://riverpod.dev). Media access: [photo_manager](https://pub.dev/packages/photo_manager).

## Getting started

Requires Flutter SDK (Dart `^3.13.3`).

```bash
flutter pub get
flutter run
```

Run tests:

```bash
flutter test
```

## Tech stack

- `flutter_riverpod` — state management
- `photo_manager` — gallery/media access
- `video_player` — video playback
- `permission_handler` — runtime permissions
- `shared_preferences` — local settings persistence
- `google_fonts` — typography
