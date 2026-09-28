class SyncStatus {
  final bool online;
  final int pendingCount;
  final int manualReviewCount;
  final bool isSyncing;

  const SyncStatus({
    this.online = true,
    this.pendingCount = 0,
    this.manualReviewCount = 0,
    this.isSyncing = false,
  });

  SyncStatus copyWith({
    bool? online,
    int? pendingCount,
    int? manualReviewCount,
    bool? isSyncing,
  }) {
    return SyncStatus(
      online: online ?? this.online,
      pendingCount: pendingCount ?? this.pendingCount,
      manualReviewCount: manualReviewCount ?? this.manualReviewCount,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}
