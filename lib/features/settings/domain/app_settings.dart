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
