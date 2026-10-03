part of '../batch_list_screen.dart';

enum _LotFilter { all, nearExpiry, expired, quarantined }

class _LotCard extends StatelessWidget {
  final BatchData batch;
  final VoidCallback onTap;
  const _LotCard({required this.batch, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = _lotStatus(batch);
    final days = batch.daysToExpiry;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWell,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  size: 22,
                  color: AppColors.navyHeader,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.supplierName.isEmpty
                          ? 'FOURNISSEUR INCONNU'
                          : batch.supplierName.toUpperCase(),
                      style: AppTypography.eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lot ${batch.batchNumber}',
                      style: AppTypography.cardTitle,
                    ),
                    Text(
                      batch.productName,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(label: status.label, tone: status.tone),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceWell,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Fact(
                    label: 'EN STOCK',
                    value: '${batch.qtyOnHand}',
                    color: batch.isEmpty ? AppColors.textSecondary : null,
                  ),
                ),
                Expanded(
                  child: _Fact(
                    label: 'DLC',
                    value: batch.expiryDate == null
                        ? '—'
                        : AppDateFormatter.date(batch.expiryDate!),
                    color: batch.isExpired
                        ? AppColors.danger
                        : batch.isNearExpiry
                            ? AppColors.warning
                            : null,
                  ),
                ),
                Expanded(
                  child: _Fact(
                    label: 'REÇU LE',
                    value: batch.receivedAt == null
                        ? '—'
                        : AppDateFormatter.date(batch.receivedAt!),
                  ),
                ),
              ],
            ),
          ),
          if (days != null && !batch.isEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              days < 0
                  ? 'Périmé depuis ${-days} jour${-days > 1 ? 's' : ''}'
                  : days == 0
                      ? 'Expire aujourd\'hui'
                      : 'Expire dans $days jour${days > 1 ? 's' : ''}',
              style: AppTypography.caption.copyWith(
                color: days < 0
                    ? AppColors.danger
                    : days <= 30
                        ? AppColors.warning
                        : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Fact({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.eyebrow.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodyStrong.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// A lot in full: where it came from, where it is now, and (for the roles that
/// may move stock) what can be done with it.
class _LotSheet extends StatelessWidget {
  final BatchData batch;
  const _LotSheet({required this.batch});

  static Future<void> show(BuildContext context, BatchData batch) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _LotSheet(batch: batch),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _lotStatus(batch);
    final canManage = getIt<SessionStore>().hasPermission('inventory.manage');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LOT ${batch.batchNumber}',
                        style: AppTypography.eyebrow,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        batch.productName,
                        style: AppTypography.sectionTitle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(label: status.label, tone: status.tone),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FormCard(
              title: 'Traçabilité',
              gap: AppSpacing.xs,
              children: [
                _SheetRow(
                  icon: Icons.local_shipping_outlined,
                  label: 'Fournisseur',
                  value: batch.supplierName.isEmpty ? '—' : batch.supplierName,
                ),
                _SheetRow(
                  icon: Icons.move_to_inbox_outlined,
                  label: 'Reçu le',
                  value: batch.receivedAt == null
                      ? '—'
                      : AppDateFormatter.dateTime(batch.receivedAt!),
                ),
                _SheetRow(
                  icon: Icons.event_busy_outlined,
                  label: batch.isExpired ? 'Périmé depuis le' : 'Expire le',
                  value: batch.expiryDate == null
                      ? 'Sans DLC'
                      : AppDateFormatter.date(batch.expiryDate!),
                  color: batch.isExpired
                      ? AppColors.danger
                      : batch.isNearExpiry
                          ? AppColors.warning
                          : null,
                ),
                _SheetRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Quantité en stock',
                  value: '${batch.qtyOnHand}',
                ),
                if (batch.isQuarantined)
                  const _SheetRow(
                    icon: Icons.block_outlined,
                    label: 'Statut',
                    value: 'En quarantaine : ne pas utiliser',
                    color: AppColors.danger,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _Where(batch: batch),
            if (canManage && !batch.isEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const Text('ACTIONS SUR CE LOT', style: AppTypography.eyebrow),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (!batch.isQuarantined) ...[
                    Expanded(
                      child: _Action(
                        icon: Icons.remove_circle_outline,
                        label: 'Sortie',
                        route: Routes.stockIssueFor(batch.id),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: _Action(
                      icon: Icons.swap_horiz,
                      label: 'Transfert',
                      route: Routes.stockTransferFor(batch.id),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _Action(
                      icon: Icons.edit_outlined,
                      label: 'Ajuster',
                      route: Routes.stockAdjustFor(batch.id),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
