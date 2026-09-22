import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/outbox/outbox_item.dart';
import '../../../../core/storage/outbox/outbox_operation.dart';
import '../../../../core/storage/outbox/outbox_status.dart';
import '../../../../core/storage/outbox/outbox_store.dart';
import '../../../../core/storage/outbox/sync_engine.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../di/di.dart';

class SyncQueueScreen extends StatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  State<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends State<SyncQueueScreen> {
  List<OutboxItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final store = getIt<OutboxStore>();
    setState(() {
      _items = store.all();
      _loading = false;
    });
  }

  Future<void> _retryAll() async {
    await getIt<SyncEngine>().flush();
    await getIt<SyncStatusCubit>().refreshNow();
    await _load();
  }

  Future<void> _retryOne(String id) async {
    await getIt<SyncEngine>().retryOne(id);
    await getIt<SyncStatusCubit>().refreshNow();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'File de synchronisation',
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _retryAll,
              icon: const Icon(Icons.sync, size: 16),
              label: const Text('Tout réessayer'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyView(
                  title: 'Aucune donnée en attente',
                  message: 'Tout est synchronisé.',
                  icon: Icons.cloud_done_outlined,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => AnimatedListItem(
                    index: i,
                    child: _QueueTile(
                      item: _items[i],
                      onRetry: () => _retryOne(_items[i].id),
                    ),
                  ),
                ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final OutboxItem item;
  final VoidCallback onRetry;

  const _QueueTile({required this.item, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          if (item.status == OutboxStatus.manualReview ||
              item.status == OutboxStatus.failed) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Réessayer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary,
                  side: const BorderSide(color: AppColors.brandPrimary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(OutboxStatus status) {
    switch (status) {
      case OutboxStatus.pending:
        return const StatusBadge(
          label: 'En attente',
          tone: StatusTone.warning,
        );
      case OutboxStatus.syncing:
        return const StatusBadge(
          label: 'En cours',
          tone: StatusTone.info,
        );
      case OutboxStatus.synced:
        return const StatusBadge(
          label: 'Synchronisé',
          tone: StatusTone.success,
        );
      case OutboxStatus.conflict:
        return const StatusBadge(
          label: 'Conflit',
          tone: StatusTone.warning,
        );
      case OutboxStatus.failed:
        return const StatusBadge(
          label: 'Échec',
          tone: StatusTone.danger,
        );
      case OutboxStatus.manualReview:
        return const StatusBadge(
          label: 'À vérifier',
          tone: StatusTone.danger,
        );
    }
  }
}
