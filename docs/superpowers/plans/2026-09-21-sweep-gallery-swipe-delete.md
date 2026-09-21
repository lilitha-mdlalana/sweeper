# Sweep — Gallery Swipe & Delete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Sweep, an Android Flutter app that lets a user rapidly clean their gallery via swipe (left=delete, right=keep, up=favourite, down=skip), never deleting anything until they explicitly confirm in a review screen.

**Architecture:** Feature-first clean architecture (`gallery`, `deletion`, `settings` features, each with `domain`/`data`/`presentation`), Riverpod for state, `photo_manager` wrapping Android MediaStore for all gallery reads/deletes — no custom platform channel unless a concrete gap appears.

**Tech Stack:** Flutter, Dart, Material 3, `flutter_riverpod`, `photo_manager`, `permission_handler`, `shared_preferences`, Google Fonts (Bricolage Grotesque + Instrument Sans).

**Spec:** `docs/superpowers/specs/2026-09-21-sweep-gallery-swipe-delete-design.md`

## Global Constraints

- Android-only for MVP. No iOS-specific work, no backend, no account, no analytics.
- No image bytes loaded beyond thumbnail resolution (~300px) except Review's single-item preview, which may use `originBytes`.
- `DeletionQueue` is in-memory/session-scoped only — never persisted to disk.
- Accent color `#C93E17` is a single theme token (`AppColors.accent`), never hardcoded inline, so it stays swappable.
- Keep button always uses `AppColors.textPrimary` (`#1B1A17`), never the accent color.
- Every screen background is `AppColors.background` (`#F5F3EE`); bottom nav bar uses `AppColors.navBackground` (`#FBFAF7`).
- Fonts: display/numerals use Bricolage Grotesque (600/800), body/UI uses Instrument Sans (400/500/600).
- `MediaRepository` is an abstract interface in `gallery/domain`; `photo_manager` only appears inside `gallery/data`.
- Each task ends with the app in a runnable state.

---

## File Structure

```
lib/
├── main.dart
├── core/
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   └── app_theme.dart
│   └── constants/
│       └── app_constants.dart
├── features/
│   ├── gallery/
│   │   ├── domain/
│   │   │   ├── media_item.dart
│   │   │   ├── media_page.dart
│   │   │   ├── sort_order.dart
│   │   │   ├── delete_result.dart
│   │   │   ├── media_repository.dart
│   │   │   ├── swipe_action.dart
│   │   │   └── gallery_state.dart
│   │   ├── data/
│   │   │   ├── photo_manager_repository.dart
│   │   │   └── thumbnail_cache.dart
│   │   └── presentation/
│   │       ├── gallery_providers.dart
│   │       ├── home_screen.dart
│   │       ├── swipe_card.dart
│   │       └── done_screen.dart
│   ├── deletion/
│   │   ├── domain/
│   │   │   └── deletion_queue.dart
│   │   └── presentation/
│   │       ├── deletion_providers.dart
│   │       ├── review_screen.dart
│   │       ├── confirm_delete_dialog.dart
│   │       └── media_preview_screen.dart
│   └── settings/
│       ├── domain/
│       │   └── app_settings.dart
│       └── presentation/
│           ├── settings_providers.dart
│           ├── settings_screen.dart
│           ├── privacy_screen.dart
│           └── permission_screen.dart
└── (app_shell.dart lives in features/gallery/presentation? -> placed at lib/core/navigation/app_shell.dart)
```

Correction applied below: bottom-nav shell lives at `lib/core/navigation/app_shell.dart` (it composes all three top-level screens, so it belongs in `core`, not one feature).

---

### Task 1: Dependencies and project bootstrap

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: working `flutter pub get` with all packages this plan needs available.

- [ ] **Step 1: Add dependencies**

Edit `pubspec.yaml`'s `dependencies:` block to:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.6.1
  photo_manager: ^3.6.4
  permission_handler: ^11.3.1
  shared_preferences: ^2.3.3
  google_fonts: ^6.2.1
```

- [ ] **Step 2: Fetch packages**

Run: `flutter pub get`
Expected: completes with no version-solve errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add riverpod, photo_manager, permission_handler, shared_preferences, google_fonts"
```

---

### Task 2: Theme tokens

**Files:**
- Create: `lib/core/theme/app_colors.dart`
- Create: `lib/core/theme/app_text_styles.dart`
- Create: `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `AppColors` (static const `Color` fields), `AppTextStyles` (static `TextStyle` getters using `GoogleFonts`), `AppTheme.light` (a `ThemeData`).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/app_theme_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/core/theme/app_theme.dart';
import 'package:sweeper/core/theme/app_colors.dart';

void main() {
  test('AppTheme.light uses Material 3 and the Sweep background color', () {
    final theme = AppTheme.light;
    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.accent);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: FAIL — `package:sweeper/core/theme/app_theme.dart` not found.

- [ ] **Step 3: Write `app_colors.dart`**

```dart
// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFFF5F3EE);
  static const surface = Color(0xFFFFFFFF);
  static const navBackground = Color(0xFFFBFAF7);
  static const textPrimary = Color(0xFF1B1A17);
  static const textSecondary = Color(0xFF6B675E);
  static const borderLight = Color(0xFFE2DED5);
  static const borderMedium = Color(0xFFE6E2D8);
  static const borderStrong = Color(0xFFCFC9BC);
  static const rowDivider = Color(0xFFEEEAE1);
  static const chipBackground = Color(0xFFECE8DF);
  static const activeNavPill = Color(0xFFE8E3D8);
  static const accent = Color(0xFFC93E17);
  static const snackbarBackground = Color(0xFF2A2825);
  static const undoLink = Color(0xFFFFB59E);
}
```

- [ ] **Step 4: Write `app_text_styles.dart`**

```dart
// lib/core/theme/app_text_styles.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle display({double size = 32, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -0.02 * size,
        color: AppColors.textPrimary,
      );

  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.textPrimary,
  }) =>
      GoogleFonts.instrumentSans(fontSize: size, fontWeight: weight, color: color);

  static TextStyle bodySecondary({double size = 14}) =>
      body(size: size, weight: FontWeight.w500, color: AppColors.textSecondary);
}
```

- [ ] **Step 5: Write `app_theme.dart`**

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
        textTheme: TextTheme(
          headlineLarge: AppTextStyles.display(size: 34),
          headlineMedium: AppTextStyles.display(size: 28),
          bodyMedium: AppTextStyles.body(),
          bodySmall: AppTextStyles.bodySecondary(),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      );
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme test/core/theme
git commit -m "feat: add Sweep theme tokens (colors, text styles, ThemeData)"
```

---

### Task 3: Navigation shell and main.dart

**Files:**
- Create: `lib/core/navigation/app_shell.dart`
- Modify: `lib/main.dart`
- Test: `test/core/navigation/app_shell_test.dart`

**Interfaces:**
- Consumes: `AppTheme.light` (Task 2).
- Produces: `AppShell` widget (a `StatefulWidget` with a `NavigationBar` and an `IndexedStack` of 3 placeholder pages, tab labels "Home"/"Review"/"Settings"), used by `main.dart` as `home`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/navigation/app_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweeper/core/navigation/app_shell.dart';

void main() {
  testWidgets('AppShell shows Home tab by default and switches to Settings on tap',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: AppShell())));

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-page')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/navigation/app_shell_test.dart`
Expected: FAIL — `app_shell.dart` not found.

- [ ] **Step 3: Write `app_shell.dart`** (placeholder pages inline; real screens replace them in later tasks)

```dart
// lib/core/navigation/app_shell.dart
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [
    Center(key: Key('home-page'), child: Text('Home')),
    Center(key: Key('review-page'), child: Text('Review')),
    Center(key: Key('settings-page'), child: Text('Settings')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.delete_outline), label: 'Review'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/navigation/app_shell_test.dart`
Expected: PASS

- [ ] **Step 5: Wire `main.dart`**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_shell.dart';

void main() {
  runApp(const ProviderScope(child: SweepApp()));
}

class SweepApp extends StatelessWidget {
  const SweepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sweep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
```

- [ ] **Step 6: Manually confirm app runs**

Run: `flutter run -d <android-device-id>`
Expected: app launches showing the bottom nav with Home/Review/Settings tabs switching correctly.

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/core/navigation test/core/navigation
git commit -m "feat: add bottom-nav app shell wired into main.dart"
```

---

### Task 4: Gallery domain models

**Files:**
- Create: `lib/features/gallery/domain/sort_order.dart`
- Create: `lib/features/gallery/domain/media_item.dart`
- Create: `lib/features/gallery/domain/media_page.dart`
- Create: `lib/features/gallery/domain/delete_result.dart`
- Create: `lib/features/gallery/domain/media_repository.dart`
- Test: `test/features/gallery/domain/media_item_test.dart`

**Interfaces:**
- Produces:
  - `enum SortOrder { newestFirst, oldestFirst }`
  - `class MediaItem { final String id; final DateTime dateTaken; final int sizeBytes; final int width; final int height; final MediaType type; MediaItem({required this.id, required this.dateTaken, required this.sizeBytes, required this.width, required this.height, this.type = MediaType.photo}); }`
  - `enum MediaType { photo, video }`
  - `class MediaPage { final List<MediaItem> items; final bool hasMore; MediaPage({required this.items, required this.hasMore}); }`
  - `class DeleteResult { final List<String> deletedIds; final List<String> failedIds; DeleteResult({required this.deletedIds, required this.failedIds}); }`
  - `abstract class MediaRepository { Future<MediaPage> getMedia({required int page, required int pageSize, required SortOrder sort}); Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}); Future<Uint8List?> getOriginalBytes(MediaItem item); Future<DeleteResult> deleteMedia(List<MediaItem> items); }`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/gallery/domain/media_item_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';

void main() {
  test('MediaItem defaults to MediaType.photo', () {
    final item = MediaItem(
      id: 'abc',
      dateTaken: DateTime(2024, 3, 14),
      sizeBytes: 3200000,
      width: 1080,
      height: 1920,
    );
    expect(item.type, MediaType.photo);
    expect(item.id, 'abc');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gallery/domain/media_item_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write `sort_order.dart`**

```dart
// lib/features/gallery/domain/sort_order.dart
enum SortOrder { newestFirst, oldestFirst }
```

- [ ] **Step 4: Write `media_item.dart`**

```dart
// lib/features/gallery/domain/media_item.dart
enum MediaType { photo, video }

class MediaItem {
  final String id;
  final DateTime dateTaken;
  final int sizeBytes;
  final int width;
  final int height;
  final MediaType type;

  MediaItem({
    required this.id,
    required this.dateTaken,
    required this.sizeBytes,
    required this.width,
    required this.height,
    this.type = MediaType.photo,
  });
}
```

- [ ] **Step 5: Write `media_page.dart`**

```dart
// lib/features/gallery/domain/media_page.dart
import 'media_item.dart';

class MediaPage {
  final List<MediaItem> items;
  final bool hasMore;

  MediaPage({required this.items, required this.hasMore});
}
```

- [ ] **Step 6: Write `delete_result.dart`**

```dart
// lib/features/gallery/domain/delete_result.dart
class DeleteResult {
  final List<String> deletedIds;
  final List<String> failedIds;

  DeleteResult({required this.deletedIds, required this.failedIds});

  int get successCount => deletedIds.length;
  int get totalCount => deletedIds.length + failedIds.length;
}
```

- [ ] **Step 7: Write `media_repository.dart`**

```dart
// lib/features/gallery/domain/media_repository.dart
import 'dart:typed_data';
import 'media_item.dart';
import 'media_page.dart';
import 'sort_order.dart';
import 'delete_result.dart';

abstract class MediaRepository {
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  });

  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300});

  Future<Uint8List?> getOriginalBytes(MediaItem item);

  Future<DeleteResult> deleteMedia(List<MediaItem> items);
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/features/gallery/domain/media_item_test.dart`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add lib/features/gallery/domain test/features/gallery/domain
git commit -m "feat: add gallery domain models (MediaItem, MediaPage, DeleteResult, MediaRepository)"
```

---

### Task 5: SwipeAction and GalleryState

**Files:**
- Create: `lib/features/gallery/domain/swipe_action.dart`
- Create: `lib/features/gallery/domain/gallery_state.dart`
- Test: `test/features/gallery/domain/gallery_state_test.dart`

**Interfaces:**
- Consumes: `MediaItem` (Task 4).
- Produces:
  - `enum SwipeAction { delete, keep, favourite, skip }`
  - `class GalleryState { final List<MediaItem> queue; final int currentIndex; final MediaItem? lastActedItem; final SwipeAction? lastAction; final int totalReviewed; final int totalMarkedForDeletion; final bool isLoading; final bool hasMorePages; ... }`
  - `GalleryState.initial()`, `GalleryState.advance({required MediaItem item, required SwipeAction action})` returning a new `GalleryState`, `GalleryState.undoLast()` returning a new `GalleryState` (or the same one if nothing to undo).
  - `MediaItem? get currentItem`, `bool get isDone`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/gallery/domain/gallery_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/domain/gallery_state.dart';
import 'package:sweeper/features/gallery/domain/swipe_action.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';

MediaItem _item(String id) => MediaItem(
      id: id,
      dateTaken: DateTime(2024, 1, 1),
      sizeBytes: 1000,
      width: 100,
      height: 100,
    );

void main() {
  test('advance moves currentIndex forward and records the action', () {
    final state = GalleryState.initial().copyWith(queue: [_item('a'), _item('b')]);

    final next = state.advance(item: _item('a'), action: SwipeAction.delete);

    expect(next.currentIndex, 1);
    expect(next.lastAction, SwipeAction.delete);
    expect(next.lastActedItem!.id, 'a');
    expect(next.totalReviewed, 1);
    expect(next.totalMarkedForDeletion, 1);
    expect(next.currentItem!.id, 'b');
  });

  test('undoLast steps currentIndex back and clears lastAction', () {
    final state = GalleryState.initial()
        .copyWith(queue: [_item('a'), _item('b')])
        .advance(item: _item('a'), action: SwipeAction.delete);

    final undone = state.undoLast();

    expect(undone.currentIndex, 0);
    expect(undone.lastAction, isNull);
    expect(undone.totalReviewed, 0);
    expect(undone.totalMarkedForDeletion, 0);
  });

  test('undoLast on fresh state is a no-op', () {
    final state = GalleryState.initial().copyWith(queue: [_item('a')]);
    final undone = state.undoLast();
    expect(undone.currentIndex, 0);
  });

  test('isDone is true once currentIndex reaches queue length', () {
    final state = GalleryState.initial()
        .copyWith(queue: [_item('a')])
        .advance(item: _item('a'), action: SwipeAction.keep);
    expect(state.isDone, isTrue);
    expect(state.currentItem, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gallery/domain/gallery_state_test.dart`
Expected: FAIL — files not found.

- [ ] **Step 3: Write `swipe_action.dart`**

```dart
// lib/features/gallery/domain/swipe_action.dart
enum SwipeAction { delete, keep, favourite, skip }
```

- [ ] **Step 4: Write `gallery_state.dart`**

```dart
// lib/features/gallery/domain/gallery_state.dart
import 'media_item.dart';
import 'swipe_action.dart';

class GalleryState {
  final List<MediaItem> queue;
  final int currentIndex;
  final MediaItem? lastActedItem;
  final SwipeAction? lastAction;
  final int totalReviewed;
  final int totalMarkedForDeletion;
  final bool isLoading;
  final bool hasMorePages;
  final int nextPage;

  const GalleryState({
    required this.queue,
    required this.currentIndex,
    required this.lastActedItem,
    required this.lastAction,
    required this.totalReviewed,
    required this.totalMarkedForDeletion,
    required this.isLoading,
    required this.hasMorePages,
    required this.nextPage,
  });

  factory GalleryState.initial() => const GalleryState(
        queue: [],
        currentIndex: 0,
        lastActedItem: null,
        lastAction: null,
        totalReviewed: 0,
        totalMarkedForDeletion: 0,
        isLoading: false,
        hasMorePages: true,
        nextPage: 0,
      );

  MediaItem? get currentItem =>
      currentIndex < queue.length ? queue[currentIndex] : null;

  bool get isDone => currentIndex >= queue.length && !hasMorePages;

  int get remaining => queue.length - currentIndex;

  GalleryState copyWith({
    List<MediaItem>? queue,
    int? currentIndex,
    MediaItem? lastActedItem,
    SwipeAction? lastAction,
    int? totalReviewed,
    int? totalMarkedForDeletion,
    bool? isLoading,
    bool? hasMorePages,
    int? nextPage,
    bool clearLastAction = false,
  }) {
    return GalleryState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      lastActedItem: clearLastAction ? null : (lastActedItem ?? this.lastActedItem),
      lastAction: clearLastAction ? null : (lastAction ?? this.lastAction),
      totalReviewed: totalReviewed ?? this.totalReviewed,
      totalMarkedForDeletion: totalMarkedForDeletion ?? this.totalMarkedForDeletion,
      isLoading: isLoading ?? this.isLoading,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      nextPage: nextPage ?? this.nextPage,
    );
  }

  GalleryState advance({required MediaItem item, required SwipeAction action}) {
    return copyWith(
      currentIndex: currentIndex + 1,
      lastActedItem: item,
      lastAction: action,
      totalReviewed: totalReviewed + 1,
      totalMarkedForDeletion:
          totalMarkedForDeletion + (action == SwipeAction.delete ? 1 : 0),
    );
  }

  GalleryState undoLast() {
    if (lastAction == null || currentIndex == 0) return this;
    final wasDelete = lastAction == SwipeAction.delete;
    return copyWith(
      currentIndex: currentIndex - 1,
      totalReviewed: totalReviewed - 1,
      totalMarkedForDeletion: totalMarkedForDeletion - (wasDelete ? 1 : 0),
      clearLastAction: true,
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/gallery/domain/gallery_state_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/gallery/domain test/features/gallery/domain
git commit -m "feat: add SwipeAction and GalleryState with advance/undo reducers"
```

---

### Task 6: DeletionQueue domain model

**Files:**
- Create: `lib/features/deletion/domain/deletion_queue.dart`
- Test: `test/features/deletion/domain/deletion_queue_test.dart`

**Interfaces:**
- Consumes: `MediaItem` (Task 4).
- Produces: `class DeletionQueue { final List<MediaItem> items; const DeletionQueue({this.items = const []}); DeletionQueue add(MediaItem item); DeletionQueue removeById(String id); DeletionQueue clear(); int get length; bool get isEmpty; }`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/deletion/domain/deletion_queue_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/deletion/domain/deletion_queue.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';

MediaItem _item(String id) => MediaItem(
      id: id,
      dateTaken: DateTime(2024, 1, 1),
      sizeBytes: 1000,
      width: 100,
      height: 100,
    );

void main() {
  test('add appends an item and removeById drops it by id', () {
    const empty = DeletionQueue();
    final withOne = empty.add(_item('a'));
    final withTwo = withOne.add(_item('b'));

    expect(withTwo.length, 2);

    final withOneAgain = withTwo.removeById('a');
    expect(withOneAgain.length, 1);
    expect(withOneAgain.items.first.id, 'b');
  });

  test('clear empties the queue', () {
    final queue = const DeletionQueue().add(_item('a')).clear();
    expect(queue.isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/deletion/domain/deletion_queue_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write `deletion_queue.dart`**

```dart
// lib/features/deletion/domain/deletion_queue.dart
import '../../gallery/domain/media_item.dart';

class DeletionQueue {
  final List<MediaItem> items;

  const DeletionQueue({this.items = const []});

  int get length => items.length;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  DeletionQueue add(MediaItem item) => DeletionQueue(items: [...items, item]);

  DeletionQueue removeById(String id) =>
      DeletionQueue(items: items.where((i) => i.id != id).toList());

  DeletionQueue clear() => const DeletionQueue();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/deletion/domain/deletion_queue_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/deletion/domain test/features/deletion/domain
git commit -m "feat: add DeletionQueue domain model"
```

---

### Task 7: Permission screen and permission_handler wiring

**Files:**
- Create: `lib/features/settings/presentation/permission_screen.dart`
- Test: `test/features/settings/presentation/permission_screen_test.dart`

**Interfaces:**
- Produces: `PermissionScreen extends ConsumerWidget` with `key: Key('permission-screen')`, callbacks `onAllowPressed` and `onPrivacyPressed` passed as constructor params (kept UI-only and callback-driven here so it's independently testable; Task 8 wires it to real `permission_handler` calls and routing).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/settings/presentation/permission_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/settings/presentation/permission_screen.dart';

void main() {
  testWidgets('tapping Allow photo access invokes onAllowPressed', (tester) async {
    var allowTapped = false;
    await tester.pumpWidget(MaterialApp(
      home: PermissionScreen(
        onAllowPressed: () => allowTapped = true,
        onPrivacyPressed: () {},
      ),
    ));

    await tester.tap(find.text('Allow photo access'));
    expect(allowTapped, isTrue);
  });

  testWidgets('tapping privacy link invokes onPrivacyPressed', (tester) async {
    var privacyTapped = false;
    await tester.pumpWidget(MaterialApp(
      home: PermissionScreen(
        onAllowPressed: () {},
        onPrivacyPressed: () => privacyTapped = true,
      ),
    ));

    await tester.tap(find.text('Read the privacy details'));
    expect(privacyTapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/permission_screen_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write `permission_screen.dart`**

```dart
// lib/features/settings/presentation/permission_screen.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PermissionScreen extends StatelessWidget {
  final VoidCallback onAllowPressed;
  final VoidCallback onPrivacyPressed;
  final bool permanentlyDenied;

  const PermissionScreen({
    super.key,
    required this.onAllowPressed,
    required this.onPrivacyPressed,
    this.permanentlyDenied = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('permission-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your photos never leave this phone.',
                  style: AppTextStyles.display(size: 30)),
              const SizedBox(height: 10),
              Text(
                permanentlyDenied
                    ? 'Photo access was denied. Enable it in Android settings to use Sweep.'
                    : 'To show your photos one at a time, Sweep needs access to your gallery. '
                        'Everything is processed on this device.',
                style: AppTextStyles.bodySecondary(size: 15),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onAllowPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: Text(
                    permanentlyDenied ? 'Open Android settings' : 'Allow photo access',
                    style: AppTextStyles.body(size: 16, weight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onPrivacyPressed,
                child: Text('Read the privacy details',
                    style: AppTextStyles.body(size: 15, weight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/permission_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/permission_screen.dart test/features/settings/presentation/permission_screen_test.dart
git commit -m "feat: add PermissionScreen UI (callback-driven, no platform calls yet)"
```

---

### Task 8: Permission provider and Android manifest wiring

**Files:**
- Create: `lib/features/settings/presentation/permission_providers.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/core/navigation/app_shell.dart` (gate the shell behind permission)
- Modify: `lib/main.dart` (route to `PermissionScreen` first)

**Interfaces:**
- Consumes: `PermissionScreen` (Task 7).
- Produces: `permissionStatusProvider` (`AsyncNotifierProvider<PermissionStatusNotifier, PermissionState>`), `enum PermissionState { unknown, granted, denied, permanentlyDenied }`, `PermissionStatusNotifier.request()`, `PermissionStatusNotifier.openSettings()`.

- [ ] **Step 1: Add manifest permissions**

Edit `android/app/src/main/AndroidManifest.xml`, inside `<manifest>` (before `<application>`):

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

- [ ] **Step 2: Write `permission_providers.dart`**

```dart
// lib/features/settings/presentation/permission_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionState { unknown, granted, denied, permanentlyDenied }

class PermissionStatusNotifier extends AsyncNotifier<PermissionState> {
  @override
  Future<PermissionState> build() async {
    final status = await Permission.photos.status;
    return _map(status);
  }

  Future<void> request() async {
    final status = await Permission.photos.request();
    state = AsyncData(_map(status));
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  PermissionState _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return PermissionState.granted;
    if (status.isPermanentlyDenied) return PermissionState.permanentlyDenied;
    return PermissionState.denied;
  }
}

final permissionStatusProvider =
    AsyncNotifierProvider<PermissionStatusNotifier, PermissionState>(
  PermissionStatusNotifier.new,
);
```

- [ ] **Step 3: Gate `main.dart` on permission state**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/app_shell.dart';
import 'features/settings/presentation/permission_screen.dart';
import 'features/settings/presentation/permission_providers.dart';
import 'features/settings/presentation/privacy_screen.dart';

void main() {
  runApp(const ProviderScope(child: SweepApp()));
}

class SweepApp extends ConsumerWidget {
  const SweepApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(permissionStatusProvider);

    return MaterialApp(
      title: 'Sweep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: permission.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const Scaffold(body: Center(child: Text('Something went wrong.'))),
        data: (state) {
          switch (state) {
            case PermissionState.granted:
              return const AppShell();
            case PermissionState.permanentlyDenied:
              return PermissionScreen(
                permanentlyDenied: true,
                onAllowPressed: () =>
                    ref.read(permissionStatusProvider.notifier).openSettings(),
                onPrivacyPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              );
            case PermissionState.unknown:
            case PermissionState.denied:
              return PermissionScreen(
                onAllowPressed: () =>
                    ref.read(permissionStatusProvider.notifier).request(),
                onPrivacyPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                ),
              );
          }
        },
      ),
    );
  }
}
```

Note: `PrivacyScreen` is created in Task 30; stub it minimally now so this compiles.

- [ ] **Step 4: Stub `PrivacyScreen` (fleshed out fully in Task 30)**

```dart
// lib/features/settings/presentation/privacy_screen.dart
import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('privacy-screen'),
      body: Center(child: Text('Privacy')),
    );
  }
}
```

- [ ] **Step 5: Manually confirm app runs and requests permission**

Run: `flutter run -d <android-device-id>`
Expected: on first launch, Permission screen shows; tapping "Allow photo access" triggers Android's system permission dialog; granting it shows `AppShell`.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml lib/features/settings/presentation/permission_providers.dart lib/features/settings/presentation/privacy_screen.dart lib/main.dart
git commit -m "feat: gate app on Android photo permission via permission_handler"
```

---

### Task 9: PhotoManagerRepository — paginated loading and thumbnails

**Files:**
- Create: `lib/features/gallery/data/photo_manager_repository.dart`
- Modify: `android/app/build.gradle.kts` (confirm `minSdk >= 21`, no change usually needed — verify only)
- Test: `test/features/gallery/data/photo_manager_repository_test.dart` (only for the pure-Dart mapping/sorting logic that doesn't require a real device — see Step 1)

**Interfaces:**
- Consumes: `MediaRepository`, `MediaItem`, `MediaPage`, `SortOrder`, `DeleteResult` (Task 4).
- Produces: `class PhotoManagerRepository implements MediaRepository`, plus a pure helper `MediaItem mapAssetToMediaItem(AssetEntity asset)` and `DeleteResult mapDeleteIdsToResult({required List<String> requestedIds, required List<String> deletedIds})` — both exposed so they're unit-testable without a device.

- [ ] **Step 1: Write the failing test (pure mapping logic only)**

```dart
// test/features/gallery/data/photo_manager_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/data/photo_manager_repository.dart';

void main() {
  test('mapDeleteIdsToResult splits requested ids into deleted vs failed', () {
    final result = mapDeleteIdsToResult(
      requestedIds: ['a', 'b', 'c'],
      deletedIds: ['a', 'c'],
    );

    expect(result.deletedIds, ['a', 'c']);
    expect(result.failedIds, ['b']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gallery/data/photo_manager_repository_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write `photo_manager_repository.dart`**

```dart
// lib/features/gallery/data/photo_manager_repository.dart
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import '../domain/media_repository.dart';
import '../domain/media_item.dart';
import '../domain/media_page.dart';
import '../domain/sort_order.dart';
import '../domain/delete_result.dart';

MediaItem mapAssetToMediaItem(AssetEntity asset) => MediaItem(
      id: asset.id,
      dateTaken: asset.createDateTime,
      sizeBytes: 0, // photo_manager doesn't expose file size synchronously; left 0 for MVP list view
      width: asset.width,
      height: asset.height,
      type: asset.type == AssetType.video ? MediaType.video : MediaType.photo,
    );

DeleteResult mapDeleteIdsToResult({
  required List<String> requestedIds,
  required List<String> deletedIds,
}) {
  final deletedSet = deletedIds.toSet();
  return DeleteResult(
    deletedIds: requestedIds.where(deletedSet.contains).toList(),
    failedIds: requestedIds.where((id) => !deletedSet.contains(id)).toList(),
  );
}

class PhotoManagerRepository implements MediaRepository {
  AssetPathEntity? _allPhotosPath;

  Future<AssetPathEntity> _getAllPhotosPath() async {
    if (_allPhotosPath != null) return _allPhotosPath!;
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      throw StateError('No photo albums available on this device.');
    }
    _allPhotosPath = paths.first;
    return _allPhotosPath!;
  }

  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  }) async {
    final path = await _getAllPhotosPath();
    final total = await path.assetCountAsync;
    final assets = await path.getAssetListPaged(page: page, size: pageSize);

    var items = assets.map(mapAssetToMediaItem).toList();
    if (sort == SortOrder.oldestFirst) {
      items = items.reversed.toList();
    }

    final loadedSoFar = (page + 1) * pageSize;
    return MediaPage(items: items, hasMore: loadedSoFar < total);
  }

  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async {
    final asset = await AssetEntity.fromId(item.id);
    if (asset == null) return null;
    return asset.thumbnailDataWithSize(ThumbnailSize.square(size));
  }

  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async {
    final asset = await AssetEntity.fromId(item.id);
    if (asset == null) return null;
    return asset.originBytes;
  }

  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async {
    final ids = items.map((i) => i.id).toList();
    final deletedIds = await PhotoManager.editor.deleteWithIds(ids);
    return mapDeleteIdsToResult(requestedIds: ids, deletedIds: deletedIds);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gallery/data/photo_manager_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Confirm Android build config is compatible**

Read `android/app/build.gradle.kts` and confirm `minSdk` resolves to at least 21 (Flutter's default `flutter.minSdkVersion` is fine — `photo_manager` requires API 21+). No edit needed if using the Flutter-generated default.

- [ ] **Step 6: Commit**

```bash
git add lib/features/gallery/data/photo_manager_repository.dart test/features/gallery/data/photo_manager_repository_test.dart
git commit -m "feat: add PhotoManagerRepository wrapping MediaStore via photo_manager"
```

---

### Task 10: Gallery providers wiring real data

**Files:**
- Create: `lib/features/gallery/presentation/gallery_providers.dart`
- Test: `test/features/gallery/presentation/gallery_providers_test.dart`

**Interfaces:**
- Consumes: `MediaRepository`, `GalleryState`, `SwipeAction`, `SortOrder` (Tasks 4, 5, 9).
- Produces: `mediaRepositoryProvider` (`Provider<MediaRepository>`, overridable in tests), `galleryProvider` (`AsyncNotifierProvider<GalleryNotifier, GalleryState>`) with methods `swipe(SwipeAction action)`, `undo()`, `loadMoreIfNeeded()`.

- [ ] **Step 1: Write the failing test (using a fake repository, no device needed)**

```dart
// test/features/gallery/presentation/gallery_providers_test.dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweeper/features/gallery/domain/media_repository.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/gallery/domain/media_page.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';
import 'package:sweeper/features/gallery/domain/delete_result.dart';
import 'package:sweeper/features/gallery/domain/swipe_action.dart';
import 'package:sweeper/features/gallery/presentation/gallery_providers.dart';

class FakeRepository implements MediaRepository {
  final List<MediaItem> allItems;
  FakeRepository(this.allItems);

  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  }) async {
    final start = page * pageSize;
    if (start >= allItems.length) return MediaPage(items: [], hasMore: false);
    final end = (start + pageSize).clamp(0, allItems.length);
    return MediaPage(items: allItems.sublist(start, end), hasMore: end < allItems.length);
  }

  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;

  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;

  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: items.map((i) => i.id).toList(), failedIds: []);
}

MediaItem _item(String id) => MediaItem(
      id: id,
      dateTaken: DateTime(2024, 1, 1),
      sizeBytes: 1000,
      width: 100,
      height: 100,
    );

void main() {
  test('galleryProvider loads the first page and swipe advances the queue', () async {
    final repo = FakeRepository([_item('a'), _item('b')]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await container.read(galleryProvider.future);
    expect(container.read(galleryProvider).value!.queue.length, 2);

    await container.read(galleryProvider.notifier).swipe(SwipeAction.delete);
    final state = container.read(galleryProvider).value!;
    expect(state.currentIndex, 1);
    expect(state.totalMarkedForDeletion, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gallery/presentation/gallery_providers_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write `gallery_providers.dart`**

```dart
// lib/features/gallery/presentation/gallery_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/photo_manager_repository.dart';
import '../domain/media_repository.dart';
import '../domain/gallery_state.dart';
import '../domain/sort_order.dart';
import '../domain/swipe_action.dart';

const int kPageSize = 60;

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return PhotoManagerRepository();
});

class GalleryNotifier extends AsyncNotifier<GalleryState> {
  @override
  Future<GalleryState> build() async {
    final repo = ref.read(mediaRepositoryProvider);
    final page = await repo.getMedia(page: 0, pageSize: kPageSize, sort: SortOrder.newestFirst);
    return GalleryState.initial().copyWith(
      queue: page.items,
      hasMorePages: page.hasMore,
      nextPage: 1,
    );
  }

  Future<void> swipe(SwipeAction action) async {
    final current = state.value;
    if (current == null || current.currentItem == null) return;
    state = AsyncData(current.advance(item: current.currentItem!, action: action));
    await loadMoreIfNeeded();
  }

  void undo() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.undoLast());
  }

  Future<void> loadMoreIfNeeded() async {
    final current = state.value;
    if (current == null || !current.hasMorePages) return;
    if (current.remaining > 10) return;

    final repo = ref.read(mediaRepositoryProvider);
    final page = await repo.getMedia(
      page: current.nextPage,
      pageSize: kPageSize,
      sort: SortOrder.newestFirst,
    );
    final latest = state.value;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(
      queue: [...latest.queue, ...page.items],
      hasMorePages: page.hasMore,
      nextPage: latest.nextPage + 1,
    ));
  }
}

final galleryProvider = AsyncNotifierProvider<GalleryNotifier, GalleryState>(
  GalleryNotifier.new,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gallery/presentation/gallery_providers_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/gallery/presentation/gallery_providers.dart test/features/gallery/presentation/gallery_providers_test.dart
git commit -m "feat: add galleryProvider wiring MediaRepository into GalleryState"
```

---

### Task 11: SwipeCard widget (gesture-to-action mapping)

**Files:**
- Create: `lib/features/gallery/presentation/swipe_card.dart`
- Test: `test/features/gallery/presentation/swipe_card_test.dart`

**Interfaces:**
- Produces: `class SwipeCard extends StatefulWidget { final Widget child; final ValueChanged<SwipeAction> onSwiped; const SwipeCard({required this.child, required this.onSwiped, super.key}); }` — wraps `child` in a `GestureDetector` handling pan gestures, calling `onSwiped` once a drag crosses a threshold in one of the four directions, animating the card off-screen first.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/gallery/presentation/swipe_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/presentation/swipe_card.dart';
import 'package:sweeper/features/gallery/domain/swipe_action.dart';

void main() {
  testWidgets('dragging left past the threshold reports SwipeAction.delete',
      (tester) async {
    SwipeAction? reported;
    await tester.pumpWidget(MaterialApp(
      home: SwipeCard(
        onSwiped: (a) => reported = a,
        child: Container(width: 300, height: 400, color: Colors.blue),
      ),
    ));

    await tester.drag(find.byType(SwipeCard), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(reported, SwipeAction.delete);
  });

  testWidgets('dragging right past the threshold reports SwipeAction.keep',
      (tester) async {
    SwipeAction? reported;
    await tester.pumpWidget(MaterialApp(
      home: SwipeCard(
        onSwiped: (a) => reported = a,
        child: Container(width: 300, height: 400, color: Colors.blue),
      ),
    ));

    await tester.drag(find.byType(SwipeCard), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(reported, SwipeAction.keep);
  });

  testWidgets('dragging up reports favourite, down reports skip', (tester) async {
    SwipeAction? reported;
    await tester.pumpWidget(MaterialApp(
      home: SwipeCard(
        onSwiped: (a) => reported = a,
        child: Container(width: 300, height: 400, color: Colors.blue),
      ),
    ));

    await tester.drag(find.byType(SwipeCard), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(reported, SwipeAction.favourite);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gallery/presentation/swipe_card_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write `swipe_card.dart`**

```dart
// lib/features/gallery/presentation/swipe_card.dart
import 'package:flutter/material.dart';
import '../domain/swipe_action.dart';

class SwipeCard extends StatefulWidget {
  final Widget child;
  final ValueChanged<SwipeAction> onSwiped;
  final double threshold;

  const SwipeCard({
    super.key,
    required this.child,
    required this.onSwiped,
    this.threshold = 120,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  Offset _drag = Offset.zero;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    final dx = _drag.dx;
    final dy = _drag.dy;
    final horizontalWins = dx.abs() >= dy.abs();

    SwipeAction? action;
    if (horizontalWins && dx <= -widget.threshold) {
      action = SwipeAction.delete;
    } else if (horizontalWins && dx >= widget.threshold) {
      action = SwipeAction.keep;
    } else if (!horizontalWins && dy <= -widget.threshold) {
      action = SwipeAction.favourite;
    } else if (!horizontalWins && dy >= widget.threshold) {
      action = SwipeAction.skip;
    }

    if (action != null) {
      widget.onSwiped(action);
    }
    setState(() => _drag = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final rotation = (_drag.dx / 300).clamp(-0.35, 0.35);
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _drag,
        child: Transform.rotate(angle: rotation, child: widget.child),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gallery/presentation/swipe_card_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/gallery/presentation/swipe_card.dart test/features/gallery/presentation/swipe_card_test.dart
git commit -m "feat: add SwipeCard widget mapping 4-directional drag to SwipeAction"
```

---

### Task 12: HomeScreen — card stack, header, progress bar

**Files:**
- Create: `lib/features/gallery/presentation/home_screen.dart`
- Test: `test/features/gallery/presentation/home_screen_test.dart`

**Interfaces:**
- Consumes: `galleryProvider`, `SwipeCard`, `mediaRepositoryProvider` (Tasks 10, 11).
- Produces: `class HomeScreen extends ConsumerWidget`, `key: Key('home-screen')`, showing header ("Clean your gallery" + remaining count), a 3-layer card stack of the current + next 2 items (thumbnails fetched via `FutureBuilder` + `mediaRepositoryProvider`), and a progress bar.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/gallery/presentation/home_screen_test.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweeper/features/gallery/domain/media_repository.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/gallery/domain/media_page.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';
import 'package:sweeper/features/gallery/domain/delete_result.dart';
import 'package:sweeper/features/gallery/presentation/gallery_providers.dart';
import 'package:sweeper/features/gallery/presentation/home_screen.dart';

class FakeRepository implements MediaRepository {
  @override
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  }) async {
    if (page > 0) return MediaPage(items: [], hasMore: false);
    return MediaPage(
      items: List.generate(
        3,
        (i) => MediaItem(
          id: 'id$i',
          dateTaken: DateTime(2024, 1, 1),
          sizeBytes: 1000,
          width: 100,
          height: 100,
        ),
      ),
      hasMore: false,
    );
  }

  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;

  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;

  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: items.map((i) => i.id).toList(), failedIds: []);
}

void main() {
  testWidgets('HomeScreen shows the remaining count from galleryProvider', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [mediaRepositoryProvider.overrideWithValue(FakeRepository())],
      child: const MaterialApp(home: HomeScreen()),
    ));

    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('remaining'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gallery/presentation/home_screen_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write `home_screen.dart`**

```dart
// lib/features/gallery/presentation/home_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/media_item.dart';
import '../domain/swipe_action.dart';
import 'gallery_providers.dart';
import 'swipe_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galleryAsync = ref.watch(galleryProvider);

    return Scaffold(
      key: const Key('home-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: galleryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load photos: $e')),
          data: (state) {
            if (state.isDone) {
              return const Center(child: Text("You're done."));
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Clean your gallery', style: AppTextStyles.bodySecondary()),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('${state.remaining}', style: AppTextStyles.display(size: 40)),
                              const SizedBox(width: 8),
                              Text('remaining',
                                  style: AppTextStyles.body(size: 16, weight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                      Text('${state.totalMarkedForDeletion} to delete',
                          style: AppTextStyles.body(size: 14, weight: FontWeight.w600, color: AppColors.accent)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: state.totalReviewed / (state.queue.length == 0 ? 1 : state.queue.length),
                      minHeight: 4,
                      backgroundColor: AppColors.borderLight,
                      valueColor: const AlwaysStoppedAnimation(AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: _CardStack(state: state, ref: ref)),
                  const SizedBox(height: 20),
                  _ActionRow(ref: ref),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CardStack extends StatelessWidget {
  final dynamic state;
  final WidgetRef ref;
  const _CardStack({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final upcoming = <MediaItem>[
      for (var i = state.currentIndex; i < state.queue.length && i < state.currentIndex + 3; i++)
        state.queue[i],
    ];
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = upcoming.length - 1; i >= 0; i--)
          if (i == 0)
            SwipeCard(
              onSwiped: (action) => ref.read(galleryProvider.notifier).swipe(action),
              child: _MediaCard(item: upcoming[0]),
            )
          else
            Transform.translate(
              offset: Offset(0, i * 8.0),
              child: Opacity(opacity: 1 - (i * 0.15), child: _MediaCard(item: upcoming[i])),
            ),
      ],
    );
  }
}

class _MediaCard extends ConsumerWidget {
  final MediaItem item;
  const _MediaCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(mediaRepositoryProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        color: AppColors.chipBackground,
        child: FutureBuilder<Uint8List?>(
          future: repo.getThumbnail(item),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done || snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          },
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final WidgetRef ref;
  const _ActionRow({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundButton(
          label: 'Delete',
          icon: Icons.close,
          background: AppColors.accent,
          foreground: Colors.white,
          onTap: () => ref.read(galleryProvider.notifier).swipe(SwipeAction.delete),
        ),
        IconButton(
          onPressed: () => ref.read(galleryProvider.notifier).undo(),
          icon: const Icon(Icons.undo),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.borderStrong),
          ),
        ),
        _RoundButton(
          label: 'Keep',
          icon: Icons.check,
          background: AppColors.textPrimary,
          foreground: Colors.white,
          onTap: () => ref.read(galleryProvider.notifier).swipe(SwipeAction.keep),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _RoundButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: foreground),
        label: Text(label, style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gallery/presentation/home_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Wire into `AppShell`**

Modify `lib/core/navigation/app_shell.dart`: replace the `'home-page'` placeholder in `_pages` with `const HomeScreen()` (import `../../features/gallery/presentation/home_screen.dart`).

- [ ] **Step 6: Manually confirm on device**

Run: `flutter run -d <android-device-id>`
Expected: Home tab shows real photo thumbnails from the device gallery, swiping and buttons advance the queue, remaining count updates.

- [ ] **Step 7: Commit**

```bash
git add lib/features/gallery/presentation/home_screen.dart lib/core/navigation/app_shell.dart test/features/gallery/presentation/home_screen_test.dart
git commit -m "feat: add HomeScreen with card stack, progress, delete/undo/keep actions"
```

---

### Task 13: Undo snackbar

**Files:**
- Modify: `lib/features/gallery/presentation/home_screen.dart`
- Modify: `lib/features/gallery/presentation/gallery_providers.dart`
- Test: `test/features/gallery/presentation/gallery_providers_test.dart` (extend)

**Interfaces:**
- Consumes: `GalleryNotifier.swipe`, `GalleryNotifier.undo` (Task 10, 12).
- Produces: `GalleryNotifier` exposes a `Stream<SwipeAction> get lastSwipeEvents` via a `StreamController` so the UI can react to a delete-swipe with a snackbar without polling state; `HomeScreen` listens and shows a `SnackBar` with an UNDO action for deletes.

- [ ] **Step 1: Extend the failing test**

Add to `test/features/gallery/presentation/gallery_providers_test.dart`:

```dart
  test('swipe(delete) emits a lastSwipeEvents event', () async {
    final repo = FakeRepository([_item('a')]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    await container.read(galleryProvider.future);
    final notifier = container.read(galleryProvider.notifier);

    final future = notifier.lastSwipeEvents.first;
    await notifier.swipe(SwipeAction.delete);

    expect(await future, SwipeAction.delete);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gallery/presentation/gallery_providers_test.dart`
Expected: FAIL — `lastSwipeEvents` not defined.

- [ ] **Step 3: Add the event stream to `GalleryNotifier`**

Edit `lib/features/gallery/presentation/gallery_providers.dart`:

```dart
import 'dart:async';
// ...existing imports...

class GalleryNotifier extends AsyncNotifier<GalleryState> {
  final _swipeEventsController = StreamController<SwipeAction>.broadcast();
  Stream<SwipeAction> get lastSwipeEvents => _swipeEventsController.stream;

  @override
  Future<GalleryState> build() async {
    ref.onDispose(_swipeEventsController.close);
    final repo = ref.read(mediaRepositoryProvider);
    final page = await repo.getMedia(page: 0, pageSize: kPageSize, sort: SortOrder.newestFirst);
    return GalleryState.initial().copyWith(
      queue: page.items,
      hasMorePages: page.hasMore,
      nextPage: 1,
    );
  }

  Future<void> swipe(SwipeAction action) async {
    final current = state.value;
    if (current == null || current.currentItem == null) return;
    state = AsyncData(current.advance(item: current.currentItem!, action: action));
    _swipeEventsController.add(action);
    await loadMoreIfNeeded();
  }

  // undo() and loadMoreIfNeeded() unchanged
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gallery/presentation/gallery_providers_test.dart`
Expected: PASS

- [ ] **Step 5: Wire the snackbar into `HomeScreen`**

In `lib/features/gallery/presentation/home_screen.dart`, change `HomeScreen` from `ConsumerWidget` to a `ConsumerStatefulWidget` so it can hold a `StreamSubscription`:

```dart
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<SwipeAction>? _sub;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _sub = ref.read(galleryProvider.notifier).lastSwipeEvents.listen((action) {
        if (action == SwipeAction.delete) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.snackbarBackground,
              duration: const Duration(seconds: 4),
              content: const Text('Photo marked for deletion', style: TextStyle(color: Colors.white)),
              action: SnackBarAction(
                label: 'UNDO',
                textColor: AppColors.undoLink,
                onPressed: () => ref.read(galleryProvider.notifier).undo(),
              ),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // body unchanged from Task 12, but reference `ref` (already available in ConsumerState)
    // ... (move the existing `build` method body from the old ConsumerWidget here verbatim)
  }
}
```

Add `import 'dart:async';` at the top of the file.

- [ ] **Step 6: Manually confirm on device**

Run: `flutter run -d <android-device-id>`
Expected: swiping/tapping delete shows the snackbar with a working UNDO action; the dedicated undo button in `_ActionRow` also restores the previous card regardless of the snackbar.

- [ ] **Step 7: Commit**

```bash
git add lib/features/gallery/presentation/home_screen.dart lib/features/gallery/presentation/gallery_providers.dart test/features/gallery/presentation/gallery_providers_test.dart
git commit -m "feat: add undo snackbar on delete swipe via GalleryNotifier event stream"
```

---

### Task 14: Wire deletions into DeletionQueue

**Files:**
- Create: `lib/features/deletion/presentation/deletion_providers.dart`
- Modify: `lib/features/gallery/presentation/gallery_providers.dart`
- Test: `test/features/deletion/presentation/deletion_providers_test.dart`

**Interfaces:**
- Consumes: `DeletionQueue` (Task 6), `GalleryNotifier.lastSwipeEvents` (Task 13).
- Produces: `deletionQueueProvider` (`NotifierProvider<DeletionQueueNotifier, DeletionQueue>`) with `add(MediaItem)`, `removeById(String)`, `restoreAll()`, `clear()`. `GalleryNotifier` gains a way for the UI layer to push the swiped item into the queue (kept as an explicit call from the listener, not a cross-provider side effect inside `GalleryNotifier`, to keep `gallery` and `deletion` decoupled per the spec's feature boundaries).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/deletion/presentation/deletion_providers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweeper/features/deletion/presentation/deletion_providers.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';

MediaItem _item(String id) => MediaItem(
      id: id, dateTaken: DateTime(2024, 1, 1), sizeBytes: 1, width: 1, height: 1,
    );

void main() {
  test('add/removeById/restoreAll manage the queue', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(deletionQueueProvider.notifier);

    notifier.add(_item('a'));
    notifier.add(_item('b'));
    expect(container.read(deletionQueueProvider).length, 2);

    notifier.removeById('a');
    expect(container.read(deletionQueueProvider).length, 1);

    notifier.clear();
    expect(container.read(deletionQueueProvider).isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/deletion/presentation/deletion_providers_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write `deletion_providers.dart`**

```dart
// lib/features/deletion/presentation/deletion_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/deletion_queue.dart';
import '../../gallery/domain/media_item.dart';

class DeletionQueueNotifier extends Notifier<DeletionQueue> {
  @override
  DeletionQueue build() => const DeletionQueue();

  void add(MediaItem item) => state = state.add(item);
  void removeById(String id) => state = state.removeById(id);
  void restoreAll() => state = state.clear();
  void clear() => state = state.clear();
}

final deletionQueueProvider = NotifierProvider<DeletionQueueNotifier, DeletionQueue>(
  DeletionQueueNotifier.new,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/deletion/presentation/deletion_providers_test.dart`
Expected: PASS

- [ ] **Step 5: Wire the listener in `HomeScreen` to push into the queue, and undo to remove it**

Edit `_HomeScreenState.initState` in `lib/features/gallery/presentation/home_screen.dart`:

```dart
      _sub = ref.read(galleryProvider.notifier).lastSwipeEvents.listen((action) {
        final justActed = ref.read(galleryProvider).value?.lastActedItem;
        if (action == SwipeAction.delete && justActed != null) {
          ref.read(deletionQueueProvider.notifier).add(justActed);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.snackbarBackground,
              duration: const Duration(seconds: 4),
              content: const Text('Photo marked for deletion', style: TextStyle(color: Colors.white)),
              action: SnackBarAction(
                label: 'UNDO',
                textColor: AppColors.undoLink,
                onPressed: () {
                  ref.read(galleryProvider.notifier).undo();
                  ref.read(deletionQueueProvider.notifier).removeById(justActed.id);
                },
              ),
            ),
          );
        }
      });
```

Also update the dedicated undo button in `_ActionRow` (Task 12) to remove from the queue too — change its `onTap`:

```dart
onTap: () {
  final lastItem = ref.read(galleryProvider).value?.lastActedItem;
  final lastAction = ref.read(galleryProvider).value?.lastAction;
  ref.read(galleryProvider.notifier).undo();
  if (lastAction == SwipeAction.delete && lastItem != null) {
    ref.read(deletionQueueProvider.notifier).removeById(lastItem.id);
  }
},
```

(`_ActionRow` needs `ref` passed in already from Task 12 — confirm the constructor still takes `WidgetRef ref`.)

- [ ] **Step 6: Manually confirm on device**

Run: `flutter run -d <android-device-id>`
Expected: deleting a photo (swipe or button) adds it to the deletion queue; UNDO (snackbar or button) removes it again.

- [ ] **Step 7: Commit**

```bash
git add lib/features/deletion/presentation/deletion_providers.dart lib/features/gallery/presentation/home_screen.dart test/features/deletion/presentation/deletion_providers_test.dart
git commit -m "feat: push deleted items into DeletionQueue, remove on undo"
```

---

### Task 15: ReviewScreen — grid, tap-to-remove, restore all

**Files:**
- Create: `lib/features/deletion/presentation/review_screen.dart`
- Test: `test/features/deletion/presentation/review_screen_test.dart`

**Interfaces:**
- Consumes: `deletionQueueProvider` (Task 14), `mediaRepositoryProvider` (Task 10).
- Produces: `class ReviewScreen extends ConsumerWidget`, `key: Key('review-screen')`, 3-column `GridView.builder` of thumbnails with a remove ("X") button per tile, header showing item count, "Restore all" and "Delete permanently" buttons (the latter wired in Task 17).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/deletion/presentation/review_screen_test.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweeper/features/gallery/domain/media_repository.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/gallery/domain/media_page.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';
import 'package:sweeper/features/gallery/domain/delete_result.dart';
import 'package:sweeper/features/gallery/presentation/gallery_providers.dart';
import 'package:sweeper/features/deletion/presentation/deletion_providers.dart';
import 'package:sweeper/features/deletion/presentation/review_screen.dart';

class NullThumbRepository implements MediaRepository {
  @override
  Future<MediaPage> getMedia({required int page, required int pageSize, required SortOrder sort}) async =>
      MediaPage(items: [], hasMore: false);
  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => null;
  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => null;
  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: items.map((i) => i.id).toList(), failedIds: []);
}

MediaItem _item(String id) => MediaItem(id: id, dateTaken: DateTime(2024, 1, 1), sizeBytes: 1, width: 1, height: 1);

void main() {
  testWidgets('ReviewScreen shows the item count and removes a tile on tap', (tester) async {
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(NullThumbRepository()),
    ]);
    addTearDown(container.dispose);
    container.read(deletionQueueProvider.notifier).add(_item('a'));
    container.read(deletionQueueProvider.notifier).add(_item('b'));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReviewScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2 items'), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-tile-a')));
    await tester.pumpAndSettle();

    expect(find.text('1 items'), findsOneWidget);
  });

  testWidgets('Restore all clears the queue', (tester) async {
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(NullThumbRepository()),
    ]);
    addTearDown(container.dispose);
    container.read(deletionQueueProvider.notifier).add(_item('a'));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReviewScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore all'));
    await tester.pumpAndSettle();

    expect(container.read(deletionQueueProvider).isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/deletion/presentation/review_screen_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write `review_screen.dart`**

```dart
// lib/features/deletion/presentation/review_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../gallery/presentation/gallery_providers.dart';
import 'deletion_providers.dart';
import 'media_preview_screen.dart';

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(deletionQueueProvider);
    final repo = ref.read(mediaRepositoryProvider);

    return Scaffold(
      key: const Key('review-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Items to delete', style: AppTextStyles.display(size: 28)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('${queue.length} items',
                        style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Tap a photo to preview it. Nothing is removed until you confirm.',
                  style: AppTextStyles.bodySecondary()),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final item = queue.items[index];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => MediaPreviewScreen(item: item)),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: FutureBuilder<Uint8List?>(
                                future: repo.getThumbnail(item),
                                builder: (context, snapshot) {
                                  if (snapshot.data == null) {
                                    return Container(color: AppColors.chipBackground);
                                  }
                                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              key: Key('remove-tile-${item.id}'),
                              icon: const Icon(Icons.close, color: Colors.white, size: 14),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                minimumSize: const Size(24, 24),
                              ),
                              onPressed: () =>
                                  ref.read(deletionQueueProvider.notifier).removeById(item.id),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.read(deletionQueueProvider.notifier).restoreAll(),
                      icon: const Icon(Icons.undo),
                      label: const Text('Restore all'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(128, 56),
                        side: const BorderSide(color: AppColors.borderStrong),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: queue.isEmpty ? null : () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          minimumSize: const Size(0, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        child: const Text('Delete permanently',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Note: "Delete permanently"'s `onPressed` is a no-op placeholder (`() {}`) here deliberately — Task 17 replaces it with the real confirm-and-delete flow. Task 16 creates `MediaPreviewScreen`, needed for this file to compile.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/deletion/presentation/review_screen_test.dart`
Expected: PASS (after Task 16's stub exists — do Step 4a first if running standalone)

- [ ] **Step 4a: If Task 16 isn't done yet, stub `MediaPreviewScreen` minimally so this compiles**

```dart
// lib/features/deletion/presentation/media_preview_screen.dart (temporary stub, replaced fully in Task 16)
import 'package:flutter/material.dart';
import '../../gallery/domain/media_item.dart';

class MediaPreviewScreen extends StatelessWidget {
  final MediaItem item;
  const MediaPreviewScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}
```

- [ ] **Step 5: Wire into `AppShell`**

Modify `lib/core/navigation/app_shell.dart`: replace `'review-page'` placeholder with `const ReviewScreen()`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/deletion/presentation/review_screen.dart lib/features/deletion/presentation/media_preview_screen.dart lib/core/navigation/app_shell.dart test/features/deletion/presentation/review_screen_test.dart
git commit -m "feat: add ReviewScreen grid with tap-to-remove and restore all"
```

---

### Task 16: MediaPreviewScreen — full tap-to-preview

**Files:**
- Modify: `lib/features/deletion/presentation/media_preview_screen.dart` (replace Task 15's stub)
- Test: `test/features/deletion/presentation/media_preview_screen_test.dart`

**Interfaces:**
- Consumes: `mediaRepositoryProvider.getOriginalBytes` (Task 4/9).
- Produces: `class MediaPreviewScreen extends ConsumerWidget { final MediaItem item; const MediaPreviewScreen({required this.item, super.key}); }` showing a full-screen `Image.memory` once original bytes load, with a loading spinner and a back button.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/deletion/presentation/media_preview_screen_test.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweeper/features/gallery/domain/media_repository.dart';
import 'package:sweeper/features/gallery/domain/media_item.dart';
import 'package:sweeper/features/gallery/domain/media_page.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';
import 'package:sweeper/features/gallery/domain/delete_result.dart';
import 'package:sweeper/features/gallery/presentation/gallery_providers.dart';
import 'package:sweeper/features/deletion/presentation/media_preview_screen.dart';

class OneByOnePngRepository implements MediaRepository {
  static final _onePixelPng = Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1,
    8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 207,
    192, 0, 0, 3, 1, 1, 0, 24, 221, 141, 176, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ]);

  @override
  Future<MediaPage> getMedia({required int page, required int pageSize, required SortOrder sort}) async =>
      MediaPage(items: [], hasMore: false);
  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async => _onePixelPng;
  @override
  Future<Uint8List?> getOriginalBytes(MediaItem item) async => _onePixelPng;
  @override
  Future<DeleteResult> deleteMedia(List<MediaItem> items) async =>
      DeleteResult(deletedIds: [], failedIds: []);
}

void main() {
  testWidgets('MediaPreviewScreen renders the image once bytes load', (tester) async {
    final item = MediaItem(id: 'a', dateTaken: DateTime(2024, 1, 1), sizeBytes: 1, width: 1, height: 1);

    await tester.pumpWidget(ProviderScope(
      overrides: [mediaRepositoryProvider.overrideWithValue(OneByOnePngRepository())],
      child: MaterialApp(home: MediaPreviewScreen(item: item)),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/deletion/presentation/media_preview_screen_test.dart`
Expected: FAIL — stub renders `SizedBox`, no `Image`.

- [ ] **Step 3: Write the real `media_preview_screen.dart`**

```dart
// lib/features/deletion/presentation/media_preview_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../gallery/domain/media_item.dart';
import '../../gallery/presentation/gallery_providers.dart';

class MediaPreviewScreen extends ConsumerWidget {
  final MediaItem item;
  const MediaPreviewScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(mediaRepositoryProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: FutureBuilder<Uint8List?>(
          future: repo.getOriginalBytes(item),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const CircularProgressIndicator();
            }
            if (snapshot.data == null) {
              return const Text('Could not load this photo.', style: TextStyle(color: Colors.white));
            }
            return InteractiveViewer(child: Image.memory(snapshot.data!));
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/deletion/presentation/media_preview_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/deletion/presentation/media_preview_screen.dart test/features/deletion/presentation/media_preview_screen_test.dart
git commit -m "feat: add full-resolution MediaPreviewScreen for Review tap-to-preview"
```

---

### Task 17: ConfirmDeleteDialog and wired permanent deletion

**Files:**
- Create: `lib/features/deletion/presentation/confirm_delete_dialog.dart`
- Modify: `lib/features/deletion/presentation/review_screen.dart`
- Modify: `lib/features/settings/domain/app_settings.dart` (created fully in Task 20 — for now, add a minimal stub so this task compiles; Task 20 replaces it)
- Test: `test/features/deletion/presentation/confirm_delete_dialog_test.dart`

**Interfaces:**
- Consumes: `DeletionQueue`, `deletionQueueProvider` (Task 6, 14), `mediaRepositoryProvider.deleteMedia` (Task 9).
- Produces: `Future<bool?> showConfirmDeleteDialog(BuildContext context, {required int itemCount})` returning `true` on confirm, `null`/`false` on cancel. `ReviewScreen`'s "Delete permanently" button calls it (gated by a `confirmBeforeDelete` setting, defaulting to `true` until Task 20 wires the real persisted value), then calls `deleteMedia` and updates the queue with only the failed items, showing a result snackbar.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/deletion/presentation/confirm_delete_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/deletion/presentation/confirm_delete_dialog.dart';

void main() {
  testWidgets('confirming the dialog resolves true, cancelling resolves false', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            result = await showConfirmDeleteDialog(context, itemCount: 24);
          },
          child: const Text('open'),
        );
      }),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 24 items permanently?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNot(true));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/deletion/presentation/confirm_delete_dialog_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write `confirm_delete_dialog.dart`**

```dart
// lib/features/deletion/presentation/confirm_delete_dialog.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

Future<bool?> showConfirmDeleteDialog(BuildContext context, {required int itemCount}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('Delete $itemCount items permanently?', style: AppTextStyles.display(size: 22)),
      content: Text(
        "They'll be removed from your device and can't be recovered. "
        'Android may ask you to allow this once more.',
        style: AppTextStyles.bodySecondary(size: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/deletion/presentation/confirm_delete_dialog_test.dart`
Expected: PASS

- [ ] **Step 5: Add a minimal `settingsProvider` stub (fleshed out in Task 20) so the wiring below compiles**

```dart
// lib/features/settings/presentation/settings_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettings {
  final bool confirmBeforeDelete;
  const AppSettings({this.confirmBeforeDelete = true});
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
```

- [ ] **Step 6: Wire "Delete permanently" in `review_screen.dart`**

Replace the placeholder `onPressed: queue.isEmpty ? null : () {}` block in `lib/features/deletion/presentation/review_screen.dart`:

```dart
import 'confirm_delete_dialog.dart';
import '../../settings/presentation/settings_providers.dart';
// ...

Expanded(
  child: ElevatedButton(
    onPressed: queue.isEmpty ? null : () => _handleDeletePermanently(context, ref, queue.length),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      minimumSize: const Size(0, 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    child: const Text('Delete permanently',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
  ),
),
```

Add this method to the `ReviewScreen` class (convert it to hold a private method, or add as a top-level function taking `context`/`ref`):

```dart
Future<void> _handleDeletePermanently(BuildContext context, WidgetRef ref, int count) async {
  final confirmBeforeDelete = ref.read(settingsProvider).confirmBeforeDelete;
  if (confirmBeforeDelete) {
    final confirmed = await showConfirmDeleteDialog(context, itemCount: count);
    if (confirmed != true) return;
  }

  final queue = ref.read(deletionQueueProvider);
  final repo = ref.read(mediaRepositoryProvider);
  final result = await repo.deleteMedia(queue.items);

  final notifier = ref.read(deletionQueueProvider.notifier);
  for (final id in result.deletedIds) {
    notifier.removeById(id);
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${result.successCount} of ${result.totalCount} deleted')),
  );
}
```

- [ ] **Step 7: Manually confirm on device**

Run: `flutter run -d <android-device-id>`
Expected: "Delete permanently" shows the confirm dialog, confirming triggers Android's own delete-confirmation UI, and successfully deleted items disappear from Review while any failures remain.

- [ ] **Step 8: Commit**

```bash
git add lib/features/deletion/presentation/confirm_delete_dialog.dart lib/features/deletion/presentation/review_screen.dart lib/features/settings/presentation/settings_providers.dart test/features/deletion/presentation/confirm_delete_dialog_test.dart
git commit -m "feat: wire confirm dialog and MediaRepository.deleteMedia into Review's delete-permanently flow"
```

---

### Task 18: DoneScreen

**Files:**
- Create: `lib/features/gallery/presentation/done_screen.dart`
- Modify: `lib/features/gallery/presentation/home_screen.dart`
- Test: `test/features/gallery/presentation/done_screen_test.dart`

**Interfaces:**
- Consumes: `GalleryState` (`isDone`, `totalReviewed`, `totalMarkedForDeletion`) (Task 5).
- Produces: `class DoneScreen extends StatelessWidget { final int totalReviewed; final int totalMarkedForDeletion; final VoidCallback onReviewDeletions; final VoidCallback onStartAgain; }`. `HomeScreen` renders it (instead of the current `Center(child: Text("You're done."))` placeholder) when `state.isDone`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/gallery/presentation/done_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/presentation/done_screen.dart';

void main() {
  testWidgets('DoneScreen shows totals and wires both buttons', (tester) async {
    var reviewTapped = false;
    var startAgainTapped = false;

    await tester.pumpWidget(MaterialApp(
      home: DoneScreen(
        totalReviewed: 428,
        totalMarkedForDeletion: 87,
        onReviewDeletions: () => reviewTapped = true,
        onStartAgain: () => startAgainTapped = true,
      ),
    ));

    expect(find.textContaining('428'), findsWidgets);
    expect(find.textContaining('87'), findsWidgets);

    await tester.tap(find.text('Review deletions'));
    expect(reviewTapped, isTrue);

    await tester.tap(find.text('Start again'));
    expect(startAgainTapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gallery/presentation/done_screen_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write `done_screen.dart`**

```dart
// lib/features/gallery/presentation/done_screen.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class DoneScreen extends StatelessWidget {
  final int totalReviewed;
  final int totalMarkedForDeletion;
  final VoidCallback onReviewDeletions;
  final VoidCallback onStartAgain;

  const DoneScreen({
    super.key,
    required this.totalReviewed,
    required this.totalMarkedForDeletion,
    required this.onReviewDeletions,
    required this.onStartAgain,
  });

  @override
  Widget build(BuildContext context) {
    final kept = totalReviewed - totalMarkedForDeletion;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Text('$totalReviewed', style: AppTextStyles.display(size: 52)),
          Text('photos', style: AppTextStyles.bodySecondary()),
          const SizedBox(height: 16),
          Text("You're done.", style: AppTextStyles.display(size: 36)),
          const SizedBox(height: 6),
          Text('You reviewed $totalReviewed photos.', style: AppTextStyles.bodySecondary(size: 17)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: [
              _Pill(color: AppColors.textPrimary, label: '$kept kept'),
              _Pill(color: AppColors.accent, label: '$totalMarkedForDeletion marked for deletion'),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onReviewDeletions,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: const Text('Review deletions',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onStartAgain,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderStrong),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              child: const Text('Start again', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Color color;
  final String label;
  const _Pill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.body(size: 14, weight: FontWeight.w500)),
      ]),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gallery/presentation/done_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Wire into `HomeScreen`**

In `lib/features/gallery/presentation/home_screen.dart`, replace `if (state.isDone) { return const Center(child: Text("You're done.")); }` with:

```dart
if (state.isDone) {
  return DoneScreen(
    totalReviewed: state.totalReviewed,
    totalMarkedForDeletion: state.totalMarkedForDeletion,
    onReviewDeletions: () {
      DefaultTabController.maybeOf(context); // no-op guard; navigation below is explicit
      Navigator.of(context).pushNamed('/review'); // see Step 6 for the alternative used
    },
    onStartAgain: () => ref.invalidate(galleryProvider),
  );
}
```

Since `AppShell` uses an `IndexedStack`, not named routes, replace the `onReviewDeletions` callback with a simpler approach: pass a `VoidCallback? onReviewDeletions` down from `AppShell` that switches its tab index. Concretely:

- [ ] **Step 6: Thread a tab-switch callback from `AppShell` down to `HomeScreen`**

Modify `lib/core/navigation/app_shell.dart`:

```dart
class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _goToReview() => setState(() => _index = 1);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onReviewDeletions: _goToReview),
      const ReviewScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.delete_outline), label: 'Review'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
```

And give `HomeScreen` a constructor param: `const HomeScreen({super.key, required this.onReviewDeletions}); final VoidCallback onReviewDeletions;` — then use `widget.onReviewDeletions` in the `DoneScreen`'s `onReviewDeletions` argument instead of the `Navigator.pushNamed` snippet above.

(`SettingsScreen` doesn't exist yet — Task 20 creates it; add a temporary stub identical in shape to the `PrivacyScreen` stub from Task 8 if doing these tasks out of order.)

- [ ] **Step 7: Manually confirm on device**

Run: `flutter run -d <android-device-id>`
Expected: swiping through the whole gallery lands on Done with correct totals; "Review deletions" switches to the Review tab; "Start again" reloads the gallery from the top.

- [ ] **Step 8: Commit**

```bash
git add lib/features/gallery/presentation/done_screen.dart lib/features/gallery/presentation/home_screen.dart lib/core/navigation/app_shell.dart test/features/gallery/presentation/done_screen_test.dart
git commit -m "feat: add DoneScreen with kept/deleted totals and review/start-again actions"
```

---

### Task 19: Thumbnail LRU cache

**Files:**
- Create: `lib/features/gallery/data/thumbnail_cache.dart`
- Modify: `lib/features/gallery/data/photo_manager_repository.dart`
- Test: `test/features/gallery/data/thumbnail_cache_test.dart`

**Interfaces:**
- Produces: `class ThumbnailCache { Uint8List? get(String id); void put(String id, Uint8List bytes); void evict(String id); }`, capped at `maxEntries` (default 30), evicting least-recently-used on overflow. `PhotoManagerRepository.getThumbnail` checks the cache before hitting `photo_manager`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/gallery/data/thumbnail_cache_test.dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/gallery/data/thumbnail_cache.dart';

void main() {
  test('put/get round-trips and evict removes an entry', () {
    final cache = ThumbnailCache(maxEntries: 2);
    final bytes = Uint8List.fromList([1, 2, 3]);

    cache.put('a', bytes);
    expect(cache.get('a'), bytes);

    cache.evict('a');
    expect(cache.get('a'), isNull);
  });

  test('overflow evicts the least-recently-used entry', () {
    final cache = ThumbnailCache(maxEntries: 2);
    cache.put('a', Uint8List.fromList([1]));
    cache.put('b', Uint8List.fromList([2]));
    cache.get('a'); // touch a, making b the LRU
    cache.put('c', Uint8List.fromList([3])); // should evict b

    expect(cache.get('a'), isNotNull);
    expect(cache.get('b'), isNull);
    expect(cache.get('c'), isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gallery/data/thumbnail_cache_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write `thumbnail_cache.dart`**

```dart
// lib/features/gallery/data/thumbnail_cache.dart
import 'dart:typed_data';

class ThumbnailCache {
  final int maxEntries;
  final _map = <String, Uint8List>{};

  ThumbnailCache({this.maxEntries = 30});

  Uint8List? get(String id) {
    final value = _map.remove(id);
    if (value == null) return null;
    _map[id] = value; // re-insert to mark as most-recently-used
    return value;
  }

  void put(String id, Uint8List bytes) {
    _map.remove(id);
    _map[id] = bytes;
    if (_map.length > maxEntries) {
      _map.remove(_map.keys.first);
    }
  }

  void evict(String id) => _map.remove(id);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gallery/data/thumbnail_cache_test.dart`
Expected: PASS

- [ ] **Step 5: Wire the cache into `PhotoManagerRepository`**

Edit `lib/features/gallery/data/photo_manager_repository.dart`:

```dart
import 'thumbnail_cache.dart';
// ...

class PhotoManagerRepository implements MediaRepository {
  final ThumbnailCache _thumbnailCache = ThumbnailCache();
  AssetPathEntity? _allPhotosPath;
  // ... _getAllPhotosPath, getMedia unchanged ...

  @override
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300}) async {
    final cached = _thumbnailCache.get(item.id);
    if (cached != null) return cached;

    final asset = await AssetEntity.fromId(item.id);
    if (asset == null) return null;
    final bytes = await asset.thumbnailDataWithSize(ThumbnailSize.square(size));
    if (bytes != null) _thumbnailCache.put(item.id, bytes);
    return bytes;
  }

  // getOriginalBytes, deleteMedia unchanged
}
```

- [ ] **Step 6: Run full test suite**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/gallery/data/thumbnail_cache.dart lib/features/gallery/data/photo_manager_repository.dart test/features/gallery/data/thumbnail_cache_test.dart
git commit -m "perf: add capped LRU thumbnail cache to PhotoManagerRepository"
```

---

### Task 20: Settings domain, provider persistence, and SettingsScreen

**Files:**
- Create: `lib/features/settings/domain/app_settings.dart`
- Modify: `lib/features/settings/presentation/settings_providers.dart` (replace Task 17's stub with the real persisted version)
- Create: `lib/features/settings/presentation/settings_screen.dart`
- Test: `test/features/settings/presentation/settings_providers_test.dart`
- Test: `test/features/settings/presentation/settings_screen_test.dart`

**Interfaces:**
- Consumes: `SortOrder` (Task 4).
- Produces: `class AppSettings { final SortOrder sortOrder; final bool confirmBeforeDelete; }` (moved from the Task 17 stub into `domain/`), `settingsProvider` now persists both fields via `shared_preferences` under keys `sweep.sortOrder` and `sweep.confirmBeforeDelete`, with `setSortOrder(SortOrder)` and `setConfirmBeforeDelete(bool)` methods. `SettingsScreen` renders the Cleaning/Gestures/About sections from the mockup and calls those methods.

- [ ] **Step 1: Write the failing provider test**

```dart
// test/features/settings/presentation/settings_providers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweeper/features/settings/presentation/settings_providers.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('setSortOrder and setConfirmBeforeDelete update state and persist', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).setSortOrder(SortOrder.oldestFirst);
    expect(container.read(settingsProvider).sortOrder, SortOrder.oldestFirst);

    await container.read(settingsProvider.notifier).setConfirmBeforeDelete(false);
    expect(container.read(settingsProvider).confirmBeforeDelete, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sweep.sortOrder'), 'oldestFirst');
    expect(prefs.getBool('sweep.confirmBeforeDelete'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/settings_providers_test.dart`
Expected: FAIL — `setSortOrder`/`setConfirmBeforeDelete` not defined on the Task 17 stub.

- [ ] **Step 3: Write `app_settings.dart`**

```dart
// lib/features/settings/domain/app_settings.dart
import '../../gallery/domain/sort_order.dart';

class AppSettings {
  final SortOrder sortOrder;
  final bool confirmBeforeDelete;

  const AppSettings({
    this.sortOrder = SortOrder.newestFirst,
    this.confirmBeforeDelete = true,
  });

  AppSettings copyWith({SortOrder? sortOrder, bool? confirmBeforeDelete}) => AppSettings(
        sortOrder: sortOrder ?? this.sortOrder,
        confirmBeforeDelete: confirmBeforeDelete ?? this.confirmBeforeDelete,
      );
}
```

- [ ] **Step 4: Replace `settings_providers.dart` with the persisted version**

```dart
// lib/features/settings/presentation/settings_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_settings.dart';
import '../../gallery/domain/sort_order.dart';

const _sortOrderKey = 'sweep.sortOrder';
const _confirmBeforeDeleteKey = 'sweep.confirmBeforeDelete';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final sortOrderName = prefs.getString(_sortOrderKey);
    final sortOrder = SortOrder.values.firstWhere(
      (o) => o.name == sortOrderName,
      orElse: () => SortOrder.newestFirst,
    );
    final confirmBeforeDelete = prefs.getBool(_confirmBeforeDeleteKey) ?? true;
    return AppSettings(sortOrder: sortOrder, confirmBeforeDelete: confirmBeforeDelete);
  }

  Future<void> setSortOrder(SortOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortOrderKey, order.name);
    state = AsyncData((state.value ?? const AppSettings()).copyWith(sortOrder: order));
  }

  Future<void> setConfirmBeforeDelete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_confirmBeforeDeleteKey, value);
    state = AsyncData((state.value ?? const AppSettings()).copyWith(confirmBeforeDelete: value));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
```

Because `settingsProvider` is now `AsyncNotifierProvider`, update the one existing call site from Task 17
(`lib/features/deletion/presentation/review_screen.dart`, `_handleDeletePermanently`) from
`ref.read(settingsProvider).confirmBeforeDelete` to
`ref.read(settingsProvider).value?.confirmBeforeDelete ?? true`.

- [ ] **Step 5: Run provider test to verify it passes**

Run: `flutter test test/features/settings/presentation/settings_providers_test.dart`
Expected: PASS

- [ ] **Step 6: Write the failing screen test**

```dart
// test/features/settings/presentation/settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweeper/features/settings/presentation/settings_screen.dart';
import 'package:sweeper/features/settings/presentation/settings_providers.dart';
import 'package:sweeper/features/gallery/domain/sort_order.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tapping Oldest updates settingsProvider sort order', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oldest'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).value?.sortOrder, SortOrder.oldestFirst);
  });

  testWidgets('toggling confirm switch updates settingsProvider', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).value?.confirmBeforeDelete, isFalse);
  });
}
```

- [ ] **Step 7: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/settings_screen_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 8: Write `settings_screen.dart`**

```dart
// lib/features/settings/presentation/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../gallery/domain/sort_order.dart';
import 'settings_providers.dart';
import 'privacy_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value;

    return Scaffold(
      key: const Key('settings-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Text('Settings', style: AppTextStyles.display(size: 32)),
            const SizedBox(height: 18),
            _SectionLabel('Cleaning'),
            const SizedBox(height: 8),
            _Card(children: [
              _Row(label: 'Media type', trailing: _Badge('Photos')),
              const Divider(height: 1, color: AppColors.rowDivider),
              _Row(
                label: 'Sort order',
                trailing: settings == null
                    ? const SizedBox.shrink()
                    : _SortToggle(
                        current: settings.sortOrder,
                        onChanged: (order) =>
                            ref.read(settingsProvider.notifier).setSortOrder(order),
                      ),
              ),
              const Divider(height: 1, color: AppColors.rowDivider),
              _Row(
                label: 'Confirm before deleting',
                subtitle: 'Ask before anything is removed for good',
                trailing: Switch(
                  value: settings?.confirmBeforeDelete ?? true,
                  onChanged: (value) =>
                      ref.read(settingsProvider.notifier).setConfirmBeforeDelete(value),
                ),
              ),
            ]),
            const SizedBox(height: 22),
            _SectionLabel('Gestures'),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.4,
              children: const [
                _GestureTile(label: 'Delete', subtitle: 'Swipe left'),
                _GestureTile(label: 'Keep', subtitle: 'Swipe right'),
                _GestureTile(label: 'Favourite', subtitle: 'Swipe up'),
                _GestureTile(label: 'Skip', subtitle: 'Swipe down'),
              ],
            ),
            const SizedBox(height: 22),
            _SectionLabel('About'),
            const SizedBox(height: 8),
            _Card(children: [
              ListTile(
                title: const Text('Privacy'),
                subtitle: const Text('Nothing leaves your phone'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              ),
              const Divider(height: 1, color: AppColors.rowDivider),
              const ListTile(
                title: Text('About Sweep'),
                subtitle: Text('A private gallery cleaner'),
                trailing: Icon(Icons.chevron_right),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderMedium),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Widget trailing;
  const _Row({required this.label, this.subtitle, required this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.body(size: 15, weight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!, style: AppTextStyles.bodySecondary(size: 13)),
              ],
            ),
          ),
          trailing,
        ]),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: Colors.white)),
      );
}

class _SortToggle extends StatelessWidget {
  final SortOrder current;
  final ValueChanged<SortOrder> onChanged;
  const _SortToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _SortButton(
        label: 'Newest',
        selected: current == SortOrder.newestFirst,
        onTap: () => onChanged(SortOrder.newestFirst),
      ),
      _SortButton(
        label: 'Oldest',
        selected: current == SortOrder.oldestFirst,
        onTap: () => onChanged(SortOrder.oldestFirst),
      ),
    ]);
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: selected ? AppColors.textPrimary : Colors.transparent,
          foregroundColor: selected ? Colors.white : AppColors.textPrimary,
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

class _GestureTile extends StatelessWidget {
  final String label;
  final String subtitle;
  const _GestureTile({required this.label, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderMedium),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTextStyles.body(size: 15, weight: FontWeight.w600)),
                Text(subtitle, style: AppTextStyles.bodySecondary(size: 13)),
              ],
            ),
          ),
        ]),
      );
}
```

- [ ] **Step 9: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/settings_screen_test.dart`
Expected: PASS

- [ ] **Step 10: Wire into `AppShell`, remove Task 18's temporary stub**

Modify `lib/core/navigation/app_shell.dart`: replace the `SettingsScreen` stub/placeholder with `const SettingsScreen()` (import `../../features/settings/presentation/settings_screen.dart`).

- [ ] **Step 11: Wire sort order into `galleryProvider`**

Edit `lib/features/gallery/presentation/gallery_providers.dart`'s `build()` and `loadMoreIfNeeded()` to read the sort order from `settingsProvider` instead of hardcoding `SortOrder.newestFirst`:

```dart
  @override
  Future<GalleryState> build() async {
    final repo = ref.read(mediaRepositoryProvider);
    final settings = await ref.read(settingsProvider.future);
    final page = await repo.getMedia(page: 0, pageSize: kPageSize, sort: settings.sortOrder);
    return GalleryState.initial().copyWith(
      queue: page.items,
      hasMorePages: page.hasMore,
      nextPage: 1,
    );
  }
```

(apply the same `settings.sortOrder` substitution in `loadMoreIfNeeded`; add `import '../../settings/presentation/settings_providers.dart';`)

- [ ] **Step 12: Manually confirm on device**

Run: `flutter run -d <android-device-id>`
Expected: Settings screen matches the mockup layout; toggling sort order changes which end of the gallery Home starts from after "Start again"; confirm-before-delete switch actually gates the dialog in Review.

- [ ] **Step 13: Commit**

```bash
git add lib/features/settings lib/features/gallery/presentation/gallery_providers.dart lib/core/navigation/app_shell.dart test/features/settings
git commit -m "feat: add persisted settings (sort order, confirm-before-delete) and SettingsScreen"
```

---

### Task 21: PrivacyScreen (full version)

**Files:**
- Modify: `lib/features/settings/presentation/privacy_screen.dart` (replace Task 8's stub)
- Test: `test/features/settings/presentation/privacy_screen_test.dart`

**Interfaces:**
- Produces: full `PrivacyScreen` matching the mockup — back button, headline, 4 bullet rows (nothing uploaded / no account / processed on-device / you confirm every deletion), an explainer card, and "Open Android settings" button wired to `permission_handler`'s `openAppSettings()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/settings/presentation/privacy_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweeper/features/settings/presentation/privacy_screen.dart';

void main() {
  testWidgets('PrivacyScreen shows all four privacy bullets', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));

    expect(find.text('Nothing is uploaded'), findsOneWidget);
    expect(find.text('No account'), findsOneWidget);
    expect(find.text('Processed on this device'), findsOneWidget);
    expect(find.text('You confirm every deletion'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/privacy_screen_test.dart`
Expected: FAIL — stub only shows "Privacy".

- [ ] **Step 3: Write the full `privacy_screen.dart`**

```dart
// lib/features/settings/presentation/privacy_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _bullets = [
    ('Nothing is uploaded', 'Photos are never sent to a server.'),
    ('No account', 'There is nothing to sign in to.'),
    ('Processed on this device', 'Thumbnails and decisions stay local.'),
    ('You confirm every deletion', 'A swipe only marks a photo.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('privacy-screen'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                Text('Privacy', style: AppTextStyles.body(size: 20, weight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              Text('Stays on your phone.', style: AppTextStyles.display(size: 36)),
              const SizedBox(height: 24),
              for (final bullet in _bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.chipBackground,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.shield_outlined, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bullet.$1, style: AppTextStyles.body(size: 16, weight: FontWeight.w600)),
                            Text(bullet.$2, style: AppTextStyles.bodySecondary()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.borderMedium),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Why Sweep asks for photo access',
                        style: AppTextStyles.body(size: 16, weight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      'Android requires this permission before any app can read your gallery. '
                      'Sweep uses it only to show your photos as cards, and to delete the ones you confirm.',
                      style: AppTextStyles.bodySecondary(size: 14),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: openAppSettings,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.borderStrong),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text('Open Android settings', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/privacy_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/privacy_screen.dart test/features/settings/presentation/privacy_screen_test.dart
git commit -m "feat: build out full PrivacyScreen matching mockup"
```

---

### Task 22: Error handling — empty gallery and vanished items

**Files:**
- Modify: `lib/features/gallery/presentation/gallery_providers.dart`
- Modify: `lib/features/gallery/presentation/home_screen.dart`
- Modify: `lib/features/gallery/data/photo_manager_repository.dart`
- Test: `test/features/gallery/presentation/gallery_providers_test.dart` (extend)

**Interfaces:**
- Consumes: `GalleryState.isDone`, `MediaRepository.getThumbnail` (Tasks 5, 9).
- Produces: `GalleryState` gains `bool get isEmpty => queue.isEmpty && !hasMorePages && !isLoading;` used by `HomeScreen` for a distinct empty-state message. `PhotoManagerRepository.getThumbnail` already returns `null` on a missing asset (Task 9's `AssetEntity.fromId` null-check) — this task adds the consuming side: `HomeScreen`'s card auto-skips to the next item if a thumbnail future resolves to `null` for more than one rebuild, rather than staying stuck.

- [ ] **Step 1: Extend the failing test**

Add to `test/features/gallery/presentation/gallery_providers_test.dart`:

```dart
  test('a gallery with zero photos reports isEmpty', () async {
    final repo = FakeRepository([]);
    final container = ProviderContainer(overrides: [
      mediaRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final state = await container.read(galleryProvider.future);
    expect(state.isEmpty, isTrue);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gallery/presentation/gallery_providers_test.dart`
Expected: FAIL — `isEmpty` not defined on `GalleryState`.

- [ ] **Step 3: Add `isEmpty` to `GalleryState`**

Edit `lib/features/gallery/domain/gallery_state.dart`, add alongside `isDone`:

```dart
  bool get isEmpty => queue.isEmpty && !hasMorePages && !isLoading;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gallery/presentation/gallery_providers_test.dart`
Expected: PASS

- [ ] **Step 5: Handle the empty state distinctly in `HomeScreen`**

In `lib/features/gallery/presentation/home_screen.dart`'s `data:` branch, add before the `isDone` check:

```dart
if (state.isEmpty) {
  return const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('No photos to clean. Your gallery is empty.'),
    ),
  );
}
```

- [ ] **Step 6: Auto-skip a vanished current item in `_CardStack`**

Edit `_MediaCard` in `lib/features/gallery/presentation/home_screen.dart` so a `null` thumbnail (item deleted externally since load) doesn't hang forever — auto-advance past it once confirmed missing:

```dart
class _MediaCard extends ConsumerWidget {
  final MediaItem item;
  final bool isCurrent;
  const _MediaCard({required this.item, this.isCurrent = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(mediaRepositoryProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        color: AppColors.chipBackground,
        child: FutureBuilder<Uint8List?>(
          future: repo.getThumbnail(item),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data == null) {
              if (isCurrent) {
                Future.microtask(() => ref.read(galleryProvider.notifier).swipe(SwipeAction.skip));
              }
              return const SizedBox.shrink();
            }
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          },
        ),
      ),
    );
  }
}
```

Update `_CardStack` to pass `isCurrent: i == 0` when constructing the front `_MediaCard` (both in the `SwipeCard`'s child and the stacked-behind ones — only the `i == 0` one needs `isCurrent: true`).

- [ ] **Step 7: Manually confirm on device**

Run: `flutter run -d <android-device-id>`
Expected: an app with zero photos shows the empty-state message instead of a spinner forever; deleting a photo via another app while Sweep is paused on it causes Sweep to silently skip it on resume rather than hanging or crashing.

- [ ] **Step 8: Commit**

```bash
git add lib/features/gallery/domain/gallery_state.dart lib/features/gallery/presentation/home_screen.dart test/features/gallery/presentation/gallery_providers_test.dart
git commit -m "fix: handle empty gallery and externally-deleted current item without hanging"
```

---

### Task 23: Final polish pass — visual audit against mockup

**Files:**
- Modify: `lib/features/gallery/presentation/home_screen.dart` (bottom-nav badge showing deletion count on the Review tab, matching mockup)
- Modify: `lib/core/navigation/app_shell.dart` (badge wiring)
- Test: `test/core/navigation/app_shell_test.dart` (extend)

**Interfaces:**
- Consumes: `deletionQueueProvider.length` (Task 14).
- Produces: `AppShell`'s Review `NavigationDestination` shows a numeric badge (via `Badge` widget) reflecting `deletionQueueProvider`'s current length, matching the mockup's red-badge-on-Review-tab detail.

- [ ] **Step 1: Extend the failing test**

Add to `test/core/navigation/app_shell_test.dart`:

```dart
  testWidgets('Review tab shows a badge with the deletion queue count', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(deletionQueueProvider.notifier).add(
      MediaItem(id: 'a', dateTaken: DateTime(2024, 1, 1), sizeBytes: 1, width: 1, height: 1),
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppShell()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsWidgets);
  });
```

Add the needed imports at the top of the test file: `import 'package:sweeper/features/deletion/presentation/deletion_providers.dart';` and `import 'package:sweeper/features/gallery/domain/media_item.dart';`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/navigation/app_shell_test.dart`
Expected: FAIL — no badge currently rendered.

- [ ] **Step 3: Add the badge to `AppShell`**

Edit `lib/core/navigation/app_shell.dart`: convert `_AppShellState.build` to read the queue length via a `Consumer` around the `NavigationBar`'s Review destination:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/deletion/presentation/deletion_providers.dart';
// ...

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onReviewDeletions: _goToReview),
      const ReviewScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Consumer(
        builder: (context, ref, _) {
          final count = ref.watch(deletionQueueProvider).length;
          return NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.photo_library_outlined), label: 'Home'),
              NavigationDestination(
                icon: count > 0
                    ? Badge(label: Text('$count'), child: const Icon(Icons.delete_outline))
                    : const Icon(Icons.delete_outline),
                label: 'Review',
              ),
              const NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
            ],
          );
        },
      ),
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/navigation/app_shell_test.dart`
Expected: PASS

- [ ] **Step 5: Run the full suite one more time**

Run: `flutter test`
Expected: all tests pass, no regressions.

- [ ] **Step 6: Manually confirm the full flow end-to-end on a real device**

Run: `flutter run -d <android-device-id>`
Expected, walking the whole app: Permission → grant → Home shows real photos → swipe/tap through several → snackbar+undo work → Review badge count matches → Review grid shows the right thumbnails → remove one → restore all → mark some again → Delete permanently → confirm dialog → Android's own confirmation → items actually gone from the device gallery → Done screen shows correct totals → Settings toggles persist across an app restart → Privacy screen matches copy.

- [ ] **Step 7: Commit**

```bash
git add lib/core/navigation/app_shell.dart test/core/navigation/app_shell_test.dart
git commit -m "feat: show deletion count badge on Review tab; final polish pass"
```

---

## Self-Review Notes

- **Spec coverage:** every spec section maps to a task — Permission (7-8), MediaRepository/photo_manager (9), domain models (4-6), swipe UI (11-12), buttons (12), undo (13), DeletionQueue (14), Review (15-16), confirmed deletion (17), Done (18), perf (19), error handling (22), Settings/Privacy (20-21), final polish (23). Video-readiness is satisfied structurally by `MediaType` in Task 4 without building video UI (correctly out of scope).
- **Placeholder scan:** the two intentional temporary stubs (`PrivacyScreen` in Task 8, `MediaPreviewScreen` in Task 15, `settingsProvider` in Task 17) are each explicitly superseded by a later numbered task, not left dangling — flagged inline at their point of use.
- **Type consistency:** `MediaRepository`/`MediaItem`/`MediaPage`/`DeleteResult` (Task 4) are used with identical signatures through Tasks 9, 10, 12, 15, 16, 17. `GalleryState` (Task 5) and its `advance`/`undoLast`/`isDone`/`isEmpty` are used consistently through Tasks 10, 12, 13, 18, 22. `DeletionQueue` (Task 6) and `deletionQueueProvider` (Task 14) keep the same method names (`add`, `removeById`, `restoreAll`, `clear`) everywhere they're called (Tasks 15, 17, 23).
- **Scope:** single cohesive app, not decomposed into sub-projects — matches the spec's own single-MVP framing.
