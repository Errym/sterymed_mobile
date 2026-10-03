import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/outbox/outbox_item.dart';
import '../../../../core/storage/key_value_store.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/storage/outbox/outbox_operation.dart';
import '../../../../core/storage/outbox/outbox_status.dart';
import '../../../../core/storage/outbox/outbox_store.dart';
import '../../../../core/storage/outbox/sync_engine.dart';
import '../../../../core/sync/sync_status_cubit.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../core/storage/outbox/sync_result.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
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
    if (!mounted) return;
    setState(() => _loading = true);
    final store = getIt<OutboxStore>();
    if (!mounted) return;
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

  Future<void> _resend(OutboxItem item) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Renvoyer cette action ?',
      message:
          'Cette action a peut-être déjà été enregistrée. Le renvoi utilise la même référence : si le serveur l’a déjà reçue, rien ne sera dupliqué. Si possible, vérifiez d’abord le dossier concerné.',
      confirmLabel: 'Renvoyer',
    );
    if (!ok || !mounted) return;
    final result = await getIt<SyncEngine>().resendUnknown(item.id);
    await getIt<SyncStatusCubit>().refreshNow();
    await _load();
    if (!mounted) return;
    AppSnackbar.show(
      context,
      result == SyncResult.success
          ? 'Action enregistrée.'
          : 'Résultat toujours à vérifier.',
      kind: result == SyncResult.success ? SnackKind.success : SnackKind.error,
    );
  }

  Future<void> _abandon(OutboxItem item) async {
    final unknown = item.status == OutboxStatus.unknownOutcome;
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Abandonner cette action ?',
      message: unknown
          ? 'Si elle a déjà été enregistrée sur le serveur, rien n’est perdu. Sinon, elle ne sera jamais enregistrée et il faudra la ressaisir. Vérifiez le dossier concerné avant de confirmer.'
          : 'Cette action ne sera pas enregistrée sur le serveur. Après correction, vous pourrez la ressaisir.',
      confirmLabel: 'Abandonner',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    final removed = await getIt<SyncEngine>().abandon(item.id);
    await getIt<SyncStatusCubit>().refreshNow();
    await _load();
    if (!mounted) return;
    AppSnackbar.show(
      context,
      removed
          ? 'Action abandonnée.'
          : 'Envoi en cours : réessayez dans un instant.',
      kind: removed ? SnackKind.success : SnackKind.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = getIt<OutboxStore>();
    final drafts = getIt<KeyValueStore>();
    final recovery = store.recoveryRequired || drafts.recoveryRequired;
    final quarantine = store.quarantineCount + drafts.quarantineCount;
    final notice = (recovery || quarantine > 0)
        ? Text(
            recovery
                ? 'Des données locales nécessitent une récupération. Les fichiers sont conservés. Contactez le responsable du cabinet avant de réinitialiser cet appareil.'
                : 'Des données anciennes sont conservées à part car leur propriétaire n’a pas pu être vérifié. Elles ne seront pas envoyées avec votre compte. Contactez le responsable du cabinet.',
          )
        : null;
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
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        if (notice != null)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: notice,
                          )
                        else
                          const EmptyView(
                            title: 'Aucune donnée en attente',
                            message: 'Tout est synchronisé.',
                            icon: Icons.cloud_done_outlined,
                          ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _items.length + (notice == null ? 0 : 1),
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, index) {
                        if (notice != null && index == 0) return notice;
                        final i = notice == null ? index : index - 1;
                        return AnimatedListItem(
                          index: i,
                          child: _QueueTile(
                            item: _items[i],
                            onRetry: () => _retryOne(_items[i].id),
                            onResend: () => _resend(_items[i]),
                            onAbandon: () => _abandon(_items[i]),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final OutboxItem item;
  final VoidCallback onRetry;
  final VoidCallback onResend;
  final VoidCallback onAbandon;

  const _QueueTile({
    required this.item,
    required this.onRetry,
    required this.onResend,
    required this.onAbandon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
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
            '${getIt<SessionStore>().userName ?? ''} — ${getIt<SessionStore>().tenantName ?? ''}',
            style: AppTypography.caption,
          ),
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
          if (item.status == OutboxStatus.unknownOutcome)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Cette action peut déjà être enregistrée. Vérifiez le dossier avec le responsable avant de la ressaisir.',
              ),
            ),
          if (_isStuck(item.status)) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (item.canResend(DateTime.now()))
                  OutlinedButton.icon(
                    onPressed: onResend,
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text('Renvoyer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandPrimary,
                      side: const BorderSide(color: AppColors.brandPrimary),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: onAbandon,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Abandonner'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ],
          if (item.status == OutboxStatus.pending ||
              item.status == OutboxStatus.authBlocked) ...[
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

  /// States the worker will never move on its own: the user must decide.
  static bool _isStuck(OutboxStatus status) =>
      status == OutboxStatus.unknownOutcome ||
      status == OutboxStatus.conflict ||
      status == OutboxStatus.validationFailed ||
      status == OutboxStatus.permissionDenied ||
      status == OutboxStatus.failed ||
      status == OutboxStatus.manualReview;

  Widget _statusBadge(OutboxStatus status) {
    switch (status) {
      case OutboxStatus.pending:
        return const StatusBadge(label: 'En attente', tone: StatusTone.warning);
      case OutboxStatus.syncing:
        return const StatusBadge(label: 'En cours', tone: StatusTone.info);
      case OutboxStatus.synced:
        return const StatusBadge(
          label: 'Synchronisé',
          tone: StatusTone.success,
        );
      case OutboxStatus.conflict:
        return const StatusBadge(label: 'Conflit', tone: StatusTone.warning);
      case OutboxStatus.failed:
        return const StatusBadge(label: 'Échec', tone: StatusTone.danger);
      case OutboxStatus.authBlocked:
        return const StatusBadge(
          label: 'Session à vérifier',
          tone: StatusTone.warning,
        );
      case OutboxStatus.permissionDenied:
        return const StatusBadge(
          label: 'Accès refusé',
          tone: StatusTone.danger,
        );
      case OutboxStatus.validationFailed:
        return const StatusBadge(
          label: 'Données à corriger',
          tone: StatusTone.danger,
        );
      case OutboxStatus.unknownOutcome:
        return const StatusBadge(
          label: 'Résultat à vérifier',
          tone: StatusTone.danger,
        );
      case OutboxStatus.manualReview:
        return const StatusBadge(label: 'À vérifier', tone: StatusTone.danger);
    }
  }
}
