enum OutboxStatus {
  pending,
  syncing,
  synced,
  conflict,
  failed,
  manualReview,
  unknownOutcome,
  authBlocked,
  permissionDenied,
  validationFailed,
}
