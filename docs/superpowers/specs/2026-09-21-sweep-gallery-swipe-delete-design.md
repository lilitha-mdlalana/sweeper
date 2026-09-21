# Sweep — Gallery Swipe & Delete: Design Spec

Date: 2026-09-21

## Purpose

Android-first Flutter app for rapidly cleaning a device photo gallery via a
Tinder-style swipe interface: swipe left to mark for deletion, right to keep,
up to favourite, down to skip. Nothing is permanently deleted until the user
explicitly confirms in a review screen. Fully local, no backend, no account.

App name: **Sweep**.

## Tech stack

- Flutter / Dart, Android-first (MVP scope: Android only, no iOS work)
- Material 3
- State management: **Riverpod** (`flutter_riverpod`)
- Gallery access & deletion: **`photo_manager`** package, wrapping Android
  MediaStore. No custom platform channel for MVP — `photo_manager`'s
  `PhotoManager.editor.deleteWithIds()` already routes through MediaStore's
  delete-request flow (`IntentSender` confirmation on API 30+, per-item
  confirmation on older APIs), which satisfies "respect Android's security
  model" without hand-rolled Kotlin. Escalate to a platform channel only if a
  concrete gap is hit during implementation.
- Persistence for settings: `shared_preferences`
- Permissions: `permission_handler`
- Fonts: Bricolage Grotesque (display/numerals) + Instrument Sans (body), via
  Google Fonts or bundled assets.

## Design tokens (from approved mockup)

Colors:
- Background: `#F5F3EE`
- Surface (cards, list rows): `#FFFFFF`
- Nav bar background: `#FBFAF7`
- Text primary: `#1B1A17`
- Text secondary: `#6B675E`
- Borders: `#E2DED5`, `#E6E2D8`, `#CFC9BC`, `#EEEAE1`
- Chip/icon-bubble background: `#ECE8DF`
- Active nav pill: `#E8E3D8`
- **Accent** (delete/danger, badges, progress bar fill on some states):
  `#C93E17` (default), user-swappable to `#1F6F5C` (teal) or `#3D4FC7` (blue)
  in Settings later (not required MVP, but keep accent as a single theme
  token so it's trivial to add)
- **Keep button uses text-primary black (`#1B1A17`), not accent** — accent is
  reserved for delete/danger actions and counts.
- Snackbar: background `#2A2825`, text `#F5F3EE`, undo action `#FFB59E`

Typography:
- Display/numerals: Bricolage Grotesque, weights 600/800
- Body/UI: Instrument Sans, weights 400/500/600

## Architecture

Feature-first clean architecture, kept intentionally shallow for MVP:

```
lib/
├── core/
│   ├── theme/        Material3 ThemeData, color + text style tokens above
│   ├── constants/
│   └── utils/
├── features/
│   ├── gallery/
│   │   ├── domain/         MediaItem, MediaRepository (interface),
│   │   │                   SwipeAction, GalleryState, SortOrder
│   │   ├── data/            PhotoManagerRepository implements MediaRepository
│   │   └── presentation/    HomeScreen (swipe UI), SwipeCard widget,
│   │                        riverpod providers/notifiers
│   ├── deletion/
│   │   ├── domain/          DeletionQueue, delete use-cases
│   │   ├── data/             delegates to gallery's MediaRepository.deleteMedia
│   │   └── presentation/    ReviewScreen, ConfirmDeleteDialog, DoneScreen
│   └── settings/
│       └── presentation/    SettingsScreen, PrivacyScreen, PermissionScreen
└── main.dart
```

`MediaRepository` contract:
```dart
abstract class MediaRepository {
  Future<MediaPage> getMedia({
    required int page,
    required int pageSize,
    required SortOrder sort,
  });
  Future<Uint8List?> getThumbnail(MediaItem item, {int size = 300});
  Future<DeleteResult> deleteMedia(List<MediaItem> items);
}
```

`MediaItem` models a photo today but is shaped so a `type` field
(`photo`/`video`) and duration/thumbnail-frame fields can be added later
without breaking callers.

## Screens (from approved mockup, in flow order)

1. **Permission** — explains local-only processing, three bullet reasons
   (reads photos to show cards / deletes only after confirm / stays
   offline), "Allow photo access" primary button, "Read the privacy
   details" link to Privacy screen.
2. **Home / Swipe** — header "Clean your gallery", big remaining count,
   "N to delete" pill (opens Review), thin progress bar, 3-card stack
   (current + 2 peeking behind), Delete / Undo / Keep button row, bottom
   nav (Home/Review/Settings).
3. **Swipe left to delete** (transient visual state of Home) — front card
   translated/rotated left with a rotated "DELETE" stamp and accent-colored
   ring, snackbar "Photo marked for deletion — UNDO" for ~4s.
4. **Done** — donut chart of kept vs marked-for-deletion, "You're done."
   headline, review count chips, "Review deletions" primary / "Start
   again" secondary buttons.
5. **Review deletions** — 3-column grid of marked thumbnails, tap removes
   from queue (X button), "Restore all" / "Delete permanently" bar pinned
   above bottom nav.
6. **Confirm deletion** — modal dialog over Review: "Delete N items
   permanently? They'll be removed from your device and can't be
   recovered. Android may ask you to allow this once more." Cancel /
   Delete buttons.
7. **Settings** — Cleaning section (media type: Photos [fixed for MVP],
   sort order Newest/Oldest toggle, Confirm-before-deleting switch),
   Gestures reference grid (Delete=swipe left, Keep=swipe right,
   Favourite=swipe up, Skip=swipe down), About section (Privacy, About
   Sweep) linking out.
8. **Privacy** — static explainer screen: nothing uploaded, no account,
   processed on-device, user confirms every deletion, why the permission
   is needed, "Open Android settings" button.

## State & data flow

Riverpod providers:
- `galleryProvider` (`AsyncNotifier<GalleryState>`) — paginated load via
  `MediaRepository.getMedia`, holds the active queue of unswiped
  `MediaItem`s, current index, preloads thumbnails for current + next 2.
- `deletionQueueProvider` (`Notifier<DeletionQueue>`) — items marked for
  deletion this session (survives navigating to Review); add / remove /
  restoreAll.
- `settingsProvider` — sort order + confirmBeforeDelete, persisted via
  `shared_preferences`.

Swipe flow:
1. Swipe/button press produces a `SwipeAction` (delete/keep/favourite/skip).
2. Delete/favourite/skip never touch disk — delete adds the `MediaItem` to
   `DeletionQueue` (in-memory), all four advance the active queue cursor.
3. On delete, show snackbar "Photo marked for deletion — UNDO" (~4s);
   tapping UNDO restores the item to the front of the queue and removes it
   from `DeletionQueue`.
4. A dedicated "undo last swipe" button replays the same undo for the most
   recent action regardless of snackbar visibility. MVP keeps a 1-deep undo
   history (extendable later).
5. Queue exhausted → Done screen with totals; "Start again" resets the
   cursor (queue re-derived from repository, keeping anything already in
   `DeletionQueue`); "Review deletions" opens Review.

Permanent delete flow:
1. Review screen renders `DeletionQueue` as a thumbnail grid; tapping an
   item removes it from the queue (does not delete).
2. "Delete permanently" — if `confirmBeforeDelete` is on, show
   `ConfirmDeleteDialog` first.
3. On confirm, call `MediaRepository.deleteMedia(queue)`, which invokes
   `photo_manager`'s delete flow (Android shows its own system
   confirmation).
4. `DeleteResult` reports success/failure per item; failed items remain in
   `DeletionQueue`; a snackbar reports "X of Y deleted."

## Large-gallery performance (target: 20,000+ photos)

- Pagination via `photo_manager`'s `getAssetListPaged`, backed by a
  MediaStore cursor — never loads the full library index into memory at
  once.
- Queue/grid hold lightweight `MediaItem` metadata only (id, dateTaken,
  size, dimensions) — no image bytes until a card is about to render.
- Thumbnails only (~300px) via `AssetEntity.thumbnailDataWithSize`, backed
  by `photo_manager`'s internal cache plus a small in-memory LRU on our
  side (capped ~30 entries; evicted as soon as a card is swiped away since
  it never renders again).
- At any time, only the current card + 2 lookahead cards + Review's
  visible grid rows (via `GridView.builder`, lazy) hold decoded image data.
- Full-resolution bytes are only fetched for Review's tap-to-preview
  single-item view — never in the swipe flow itself.

## Error handling

- Permission denied → stay on Permission screen with explanation.
- Permission permanently denied → same screen, adjusted copy, "Open
  Android settings" is then the only path forward.
- Empty gallery → empty-state variant of Done screen ("No photos to
  clean").
- Item disappears between load and swipe (deleted externally) → catch the
  null/exception from `photo_manager`, auto-skip to the next item, never
  crash.
- Partial delete failure → `DeleteResult` is per-item; failures stay in
  `DeletionQueue`; user sees "X of Y deleted."
- App backgrounded during a delete call → the delete is a single awaited
  Future; Android/Flutter own the in-flight op; on resume the UI simply
  re-renders current provider state. No special handling needed for MVP.
- Unsupported/corrupt media → treat like a vanished item: skip, don't crash.

## Out of scope for MVP (per original brief)

Auth, backend, cloud storage, social features, AI photo analysis,
duplicate detection, subscriptions/payments, ads, iOS, complex analytics,
video support (model is shaped to allow it later, not built now).

## Testing approach

- Unit tests for `DeletionQueue`, `GalleryState` reducers/notifiers, and
  `SwipeAction` handling — pure Dart, no platform dependency.
- Widget tests for `SwipeCard` gesture-to-action mapping and the Review
  grid's add/remove behavior, using a fake `MediaRepository`.
- Manual on-device verification against a real Android device with a real
  gallery is required before considering any phase "done" per the original
  brief's engineering constraint — mock media only during initial UI
  scaffolding, real MediaStore integration from the gallery-access phase
  onward.

## Development phases (incremental, each phase leaves the app runnable)

1. Project setup, theme (tokens above), navigation shell (Home/Review/Settings)
2. Android media permission flow (Permission screen, `permission_handler`)
3. `MediaRepository` + `photo_manager` integration, paginated real-photo
   loading (mock data allowed only before this point)
4. `MediaItem` / `GalleryState` / `SwipeAction` domain models
5. Swipe-card UI (custom `GestureDetector`, stacked cards, 4-direction swipe)
6. Keep/delete/favourite/skip button row mirroring swipe gestures
7. Undo (snackbar + dedicated button)
8. `DeletionQueue` (in-memory, session-scoped)
9. Review screen (grid, tap-to-preview, remove-from-queue, restore all)
10. Confirmed permanent deletion (`ConfirmDeleteDialog` + `deleteMedia`)
11. Large-gallery performance pass (pagination tuning, thumbnail cache caps)
12. Error handling pass (all cases above)
13. Settings + Privacy screens
14. Final UI polish against mockup fidelity
