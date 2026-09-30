import '../../gallery/domain/sort_order.dart';

class AppSettings {
  final SortOrder sortOrder;
  final bool confirmBeforeDelete;
  final String? selectedAlbumName;

  const AppSettings({
    this.sortOrder = SortOrder.newestFirst,
    this.confirmBeforeDelete = true,
    this.selectedAlbumName,
  });

  AppSettings copyWith({
    SortOrder? sortOrder,
    bool? confirmBeforeDelete,
    String? selectedAlbumName,
    bool clearSelectedAlbumName = false,
  }) =>
      AppSettings(
        sortOrder: sortOrder ?? this.sortOrder,
        confirmBeforeDelete: confirmBeforeDelete ?? this.confirmBeforeDelete,
        selectedAlbumName:
            clearSelectedAlbumName ? null : (selectedAlbumName ?? this.selectedAlbumName),
      );
}
