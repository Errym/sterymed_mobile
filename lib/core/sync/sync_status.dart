class SyncStatus {
  final bool localRecoveryRequired;
  final int quarantinedCount;
  final bool online;
  final int pendingCount;
  final int manualReviewCount;
  final bool isSyncing;

  const SyncStatus({
    this.localRecoveryRequired = false,
    this.quarantinedCount = 0,
    this.online = true,
    this.pendingCount = 0,
    this.manualReviewCount = 0,
    this.isSyncing = false,
  });

  SyncStatus copyWith({
    bool? localRecoveryRequired,
    int? quarantinedCount,
    bool? online,
    int? pendingCount,
    int? manualReviewCount,
    bool? isSyncing,
  }) {
    return SyncStatus(
      localRecoveryRequired:
          localRecoveryRequired ?? this.localRecoveryRequired,
      quarantinedCount: quarantinedCount ?? this.quarantinedCount,
      online: online ?? this.online,
      pendingCount: pendingCount ?? this.pendingCount,
      manualReviewCount: manualReviewCount ?? this.manualReviewCount,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}
