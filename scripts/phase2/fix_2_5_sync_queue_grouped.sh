#!/usr/bin/env bash
source "$(dirname "$0")/../phase1/_common.sh"

banner "FIX 2.5 — Sync queue grouping + bulk actions"

require_repo_root
require_clean_tree

STORE="lib/core/storage/outbox/outbox_store.dart"
ENGINE="lib/core/storage/outbox/sync_engine.dart"
SCREEN="lib/features/sync/presentation/screens/sync_queue_screen.dart"

backup_file "$STORE"
backup_file "$ENGINE"
backup_file "$SCREEN"

# ── 1. Ensure OutboxStore.removeMany exists ───────────────────────────
if grep -q "Future<void> removeMany" "$STORE"; then
  ok "OutboxStore.removeMany already present"
else
  python3 - "$STORE" <<'PYEOF'
import io, sys

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

method = '''
  Future<void> removeMany(Iterable<String> ids) async {
    for (final id in ids) {
      await _box.delete(id);
    }
    await _box.flush();
  }
'''

anchor = "  Future<void> remove(String id) async {"
if anchor not in src:
    # Fall back: insert before clear().
    anchor = "  Future<void> clear() async {"
if anchor not in src:
    print("Neither remove nor clear found — insert removeMany manually", file=sys.stderr)
    sys.exit(1)

src = src.replace(anchor, method + "\n" + anchor, 1)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Added removeMany to OutboxStore")
PYEOF
fi

# ── 2. Ensure SyncEngine.retryMany exists ─────────────────────────────
if grep -q "Future<int> retryMany" "$ENGINE"; then
  ok "SyncEngine.retryMany already present"
else
  python3 - "$ENGINE" <<'PYEOF'
import io, sys

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

method = '''
  /// Retry multiple items in sequence. Returns the number that succeeded.
  Future<int> retryMany(List<String> ids) async {
    int ok = 0;
    for (final id in ids) {
      final r = await retryOne(id);
      if (r == SyncResult.success) ok++;
    }
    return ok;
  }
'''

anchor = "  /// Manually retry one item (from the queue screen)."
if anchor not in src:
    # Append at end of class (before final closing brace).
    last_brace = src.rstrip().rfind("}")
    src = src[:last_brace] + method + "\n" + src[last_brace:]
else:
    src = src.replace(anchor, method + "\n" + anchor, 1)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Added retryMany to SyncEngine")
PYEOF
fi

# ── 3. Rewrite sync queue screen ─────────────────────────────────────
cat > "$SCREEN" <<'DART'
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/outbox/outbox_item.dart';
import '../../../../core/storage/outbox/outbox_operation.dart';
import '../../../../core/storage/outbox/outbox_status.dart';
import '../../../../core/storage/outbox/outbox_store.dart';
import '../../../../core/storage/outbox/sync_engine.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';

enum _QueueFilter { all, pending, manualReview, failed }

class SyncQueueScreen extends StatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  State<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends State<SyncQueueScreen> {
  List<OutboxItem> _items = [];
  bool _loading = true;
  _QueueFilter _filter = _QueueFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final store = getIt<OutboxStore>();
    if (!mounted) return;
    setState(() {
      _items = store.all();
      _loading = false;
    });
  }

  List<OutboxItem> get _pending => _items
      .where((i) => i.status == OutboxStatus.pending)
      .toList();

  List<OutboxItem> get _failed => _items
      .where((i) => i.status == OutboxStatus.failed)
      .toList();

  List<OutboxItem> get _manual => _items
      .where((i) => i.status == OutboxStatus.manualReview)
      .toList();

  bool _showSection(String key) {
    switch (_filter) {
      case _QueueFilter.all:
        return true;
      case _QueueFilter.pending:
        return key == 'pending';
      case _QueueFilter.manualReview:
        return key == 'manual';
      case _QueueFilter.failed:
        return key == 'failed';
    }
  }

  Future<void> _retryAll() async {
    final ids = [..._pending.map((i) => i.id), ..._failed.map((i) => i.id)];
    if (ids.isEmpty) return;
    await getIt<SyncEngine>().retryMany(ids);
    await getIt<SyncStatusCubit>().refreshNow();
    await _load();
  }

  Future<void> _retryOne(String id) async {
    await getIt<SyncEngine>().retryOne(id);
    await getIt<SyncStatusCubit>().refreshNow();
    await _load();
  }

  Future<void> _deleteOne(OutboxItem item) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Supprimer cette écriture ?',
      message: '${item.operation.label}\n\nCette action est irréversible.',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    await getIt<OutboxStore>().removeMany([item.id]);
    await getIt<SyncStatusCubit>().refreshNow();
    await _load();
  }

  Future<void> _clearManual() async {
    if (_manual.isEmpty) return;
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Effacer tous les éléments à vérifier ?',
      message: '${_manual.length} écriture(s) seront définitivement '
          'supprimées. Assurez-vous d\'avoir traité les cas concernés.',
      confirmLabel: 'Effacer',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    await getIt<OutboxStore>().removeMany(_manual.map((i) => i.id));
    await getIt<SyncStatusCubit>().refreshNow();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'File de synchronisation',
        showSyncPill: false,
        actions: [
          PopupMenuButton<_QueueFilter>(
            icon: const Icon(Icons.filter_list),
            initialValue: _filter,
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _QueueFilter.all,
                child: Text('Tous'),
              ),
              PopupMenuItem(
                value: _QueueFilter.pending,
                child: Text('En attente'),
              ),
              PopupMenuItem(
                value: _QueueFilter.manualReview,
                child: Text('À vérifier'),
              ),
              PopupMenuItem(
                value: _QueueFilter.failed,
                child: Text('Échecs'),
              ),
            ],
          ),
          if (_pending.isNotEmpty || _failed.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Tout réessayer',
              onPressed: _retryAll,
            ),
          if (_manual.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Effacer tout (à vérifier)',
              onPressed: _clearManual,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        EmptyView(
                          title: 'Aucune donnée en attente',
                          message: 'Tout est synchronisé.',
                          icon: Icons.cloud_done_outlined,
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        if (_showSection('manual') && _manual.isNotEmpty) ...[
                          _sectionHeader('À vérifier', _manual.length, AppColors.danger),
                          for (final item in _manual)
                            AnimatedListItem(
                              index: item.id.hashCode,
                              child: _QueueTile(
                                item: item,
                                onRetry: () => _retryOne(item.id),
                                onDelete: () => _deleteOne(item),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (_showSection('failed') && _failed.isNotEmpty) ...[
                          _sectionHeader('Échecs', _failed.length, AppColors.danger),
                          for (final item in _failed)
                            AnimatedListItem(
                              index: item.id.hashCode,
                              child: _QueueTile(
                                item: item,
                                onRetry: () => _retryOne(item.id),
                                onDelete: () => _deleteOne(item),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (_showSection('pending') && _pending.isNotEmpty) ...[
                          _sectionHeader('En attente', _pending.length, AppColors.warning),
                          for (final item in _pending)
                            AnimatedListItem(
                              index: item.id.hashCode,
                              child: _QueueTile(item: item),
                            ),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _sectionHeader(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label ($count)',
            style: AppTypography.bodyStrong.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final OutboxItem item;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  const _QueueTile({required this.item, this.onRetry, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.operation.label,
                  style: AppTypography.bodyStrong,
                ),
              ),
              _statusBadge(item.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt),
            style: AppTypography.caption,
          ),
          if (item.retryCount > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Tentatives : ${item.retryCount}',
              style: AppTypography.caption,
            ),
          ],
          if (item.lastError != null) ...[
            const SizedBox(height: 2),
            Text(
              item.lastError!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ],
          if (onRetry != null || onDelete != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (onRetry != null)
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Réessayer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandPrimary,
                      side: const BorderSide(color: AppColors.brandPrimary),
                    ),
                  ),
                const Spacer(),
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.danger),
                    label: const Text(
                      'Supprimer',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(OutboxStatus status) {
    switch (status) {
      case OutboxStatus.pending:
        return const StatusBadge(label: 'En attente', tone: StatusTone.warning);
      case OutboxStatus.syncing:
        return const StatusBadge(label: 'En cours', tone: StatusTone.info);
      case OutboxStatus.synced:
        return const StatusBadge(label: 'Synchronisé', tone: StatusTone.success);
      case OutboxStatus.conflict:
        return const StatusBadge(label: 'Conflit', tone: StatusTone.warning);
      case OutboxStatus.failed:
        return const StatusBadge(label: 'Échec', tone: StatusTone.danger);
      case OutboxStatus.manualReview:
        return const StatusBadge(label: 'À vérifier', tone: StatusTone.danger);
    }
  }
}
DART
ok "Rewrote sync_queue_screen.dart"

run_analyze
run_tests
commit_fix "feat(sync): grouped queue with retry, delete, and filters" \
  "$STORE" "$ENGINE" "$SCREEN"

ok "FIX 2.5 complete"