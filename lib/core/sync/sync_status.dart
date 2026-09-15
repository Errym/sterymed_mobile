class SyncStatus {
  final bool online;
  final int pendingCount;
  final int manualReviewCount;

  const SyncStatus({
    this.online = true,
    this.pendingCount = 0,
    this.manualReviewCount = 0,
  });

  SyncStatus copyWith({
    bool? online,
    int? pendingCount,
    int? manualReviewCount,
  }) {
    return SyncStatus(
      online: online ?? this.online,
      pendingCount: pendingCount ?? this.pendingCount,
      manualReviewCount: manualReviewCount ?? this.manualReviewCount,
    );
  }
}