class DeleteResult {
  final List<String> deletedIds;
  final List<String> failedIds;

  DeleteResult({required this.deletedIds, required this.failedIds});

  int get successCount => deletedIds.length;
  int get totalCount => deletedIds.length + failedIds.length;
}
