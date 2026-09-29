#!/usr/bin/env bash
source "$(dirname "$0")/../phase1/_common.sh"

banner "FIX 2.7 — Route all writes through the outbox"

require_repo_root
require_clean_tree

OUTBOX_OP="lib/core/storage/outbox/outbox_operation.dart"

backup_file "$OUTBOX_OP"

# ── 1. Extend OutboxOperation enum ────────────────────────────────────
cat > "$OUTBOX_OP" <<'DART'
enum OutboxOperation {
  labelUsage,
  stockIssue,
  stockAdjust,
  stockTransfer,
  goodsReceipt,
  cycleTransition,
  maintenanceRecord,
  deviceProgram,
  product,
  supplier,
  dluRule,
  nonConformity,
}

extension OutboxOperationLabel on OutboxOperation {
  String get label {
    switch (this) {
      case OutboxOperation.labelUsage:
        return 'Utilisation étiquette';
      case OutboxOperation.stockIssue:
        return 'Sortie de stock';
      case OutboxOperation.stockAdjust:
        return 'Ajustement de stock';
      case OutboxOperation.stockTransfer:
        return 'Transfert de stock';
      case OutboxOperation.goodsReceipt:
        return 'Réception marchandise';
      case OutboxOperation.cycleTransition:
        return 'Transition cycle';
      case OutboxOperation.maintenanceRecord:
        return 'Fiche de maintenance';
      case OutboxOperation.deviceProgram:
        return 'Programme appareil';
      case OutboxOperation.product:
        return 'Produit';
      case OutboxOperation.supplier:
        return 'Fournisseur';
      case OutboxOperation.dluRule:
        return 'Règle DLU';
      case OutboxOperation.nonConformity:
        return 'Non-conformité';
    }
  }
}
DART
ok "Extended OutboxOperation enum"

run_analyze
commit_fix "feat(offline): extend OutboxOperation enum with 6 new write types" "$OUTBOX_OP"

# ── 2. Print the wiring plan for each repository ──────────────────────
cat <<'PLAN'

════════════════════════════════════════════════════════════════
  FIX 2.7 — MANUAL WIRING PLAN
════════════════════════════════════════════════════════════════

The enum is extended. Now wire each repository to route writes through
the outbox. The pattern is IDENTICAL across all 6 — copy StockRepository's
pattern (already implemented) into each.

For each repository listed below, do the following:

  1. Add imports:
       import '../../../../core/errors/api_exception.dart';
       import '../../../../core/storage/outbox/outbox_item.dart';
       import '../../../../core/storage/outbox/outbox_operation.dart';
       import '../../../../core/storage/outbox/outbox_store.dart';
       import '../../../../core/sync/connectivity_service.dart';
       import '../../../../core/sync/sync_status_cubit.dart';
       import '../../../../core/utils/idempotency_key.dart';

  2. Add constructor params (like StockRepository):
       required OutboxStore outbox,
       required ConnectivityService connectivity,
       required SyncStatusCubit syncStatus,

  3. Wrap the write method in the _submitWrite helper:
       - Try online first.
       - On network/timeout error, enqueue an OutboxItem.
       - Return a synthetic model with `isQueued: true`.

  4. Update the DI registration in lib/di/features_di.dart to pass
     outbox, connectivity, syncStatus.

  5. Update the UI to check `result.isQueued` and show the queued snackbar.

════════════════════════════════════════════════════════════════
  REPOSITORY 1: MaintenanceRecordRepository
════════════════════════════════════════════════════════════════

  Endpoint: POST /v1/devices/{deviceId}/maintenance-records
  Operation: OutboxOperation.maintenanceRecord

  In lib/features/devices/data/repositories/maintenance_record_repository.dart,
  wrap the create() method with the same pattern as StockRepository._submitWrite.

════════════════════════════════════════════════════════════════
  REPOSITORY 2: DeviceProgramRepository
════════════════════════════════════════════════════════════════

  Endpoint: POST /v1/devices/{deviceId}/programs
  Operation: OutboxOperation.deviceProgram

  In lib/features/cycles/data/repositories/device_program_repository.dart,
  wrap create() (and optionally update(), destroy()).

════════════════════════════════════════════════════════════════
  REPOSITORY 3: ProductRepository
════════════════════════════════════════════════════════════════

  Endpoint: POST /v1/products
  Operation: OutboxOperation.product

  In lib/features/catalog/data/repositories/product_repository.dart,
  wrap create(), update(), destroy().

════════════════════════════════════════════════════════════════
  REPOSITORY 4: SupplierRepository
════════════════════════════════════════════════════════════════

  Endpoint: POST /v1/suppliers
  Operation: OutboxOperation.supplier

  In lib/features/suppliers/data/repositories/supplier_repository.dart,
  wrap create(), update(), destroy().

════════════════════════════════════════════════════════════════
  REPOSITORY 5: DluRepository
════════════════════════════════════════════════════════════════

  Endpoint: POST /v1/dlu-rules
  Operation: OutboxOperation.dluRule

  In lib/features/dlu/data/repositories/dlu_repository.dart,
  wrap create(), update(), destroy().

════════════════════════════════════════════════════════════════
  REPOSITORY 6: NonConformityRepository
════════════════════════════════════════════════════════════════

  Endpoint: POST /v1/non-conformities
  Operation: OutboxOperation.nonConformity

  In lib/features/compliance/data/repositories/non_conformity_repository.dart,
  wrap create() and resolve().

════════════════════════════════════════════════════════════════
  REFERENCE: StockRepository._submitWrite
════════════════════════════════════════════════════════════════

Copy this pattern verbatim, adjusting for the model type:

  Future<XModel> _submitWrite({
    required OutboxOperation operation,
    required String endpoint,
    required Map<String, dynamic> payload,
    required Future<XModel> Function() online,
    required XModel Function(String id) synthetic,
  }) async {
    final isOnline = await _connectivity.isConnected;
    if (isOnline) {
      try {
        final result = await online();
        _cache.invalidateAll();
        return result;
      } on ApiException catch (e) {
        if (!e.isNetwork && !e.isTimeout) rethrow;
      }
    }

    final itemId = generateIdempotencyKey();
    await _outbox.enqueue(OutboxItem(
      id: itemId,
      operation: operation,
      endpoint: endpoint,
      method: 'POST',
      payload: payload,
      idempotencyKey: generateIdempotencyKey(),
      createdAt: DateTime.now(),
    ));
    _syncStatus.refreshNow();
    return synthetic(itemId);
  }

════════════════════════════════════════════════════════════════
  ESTIMATED TIME: 4-6 hours total (1h per repository, including tests)
════════════════════════════════════════════════════════════════

Commit after each repository. Message format:

  feat(offline): route <entity> writes through the outbox

PLAN

ok "FIX 2.7 started — enum extended, wiring plan printed above"
warn "This fix is not complete until all 6 repositories are wired + tested."
warn "Follow the plan above, commit each repository separately."