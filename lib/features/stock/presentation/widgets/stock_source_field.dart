import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../data/models/stock_level_data.dart';
import '../../data/pending_stock_delta.dart';
import '../../domain/stock_rules.dart';

/// Picks WHERE stock comes from: one row of "this lot, at this place, this many
/// available". Replaces two unrelated dropdowns (lot, place) that let the user
/// combine a lot with a place where it is not, then fail on the server.
///
/// Rows are searchable (product, reference, lot, place) and listed with the
/// soonest expiry first. A quarantined lot is shown but cannot be chosen.
class StockSourceField extends StatelessWidget {
  final String label;
  final List<StockLevelData> rows;
  final StockLevelData? selected;
  final PendingStockDelta pending;
  final ValueChanged<StockLevelData> onSelected;

  /// A quarantined lot cannot be used up or moved, but a correction may still
  /// be recorded against it.
  final bool allowQuarantined;

  const StockSourceField({
    super.key,
    required this.rows,
    required this.selected,
    required this.onSelected,
    this.label = 'Lot et emplacement *',
    this.pending = PendingStockDelta.empty,
    this.allowQuarantined = false,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<StockLevelData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _SourceSheet(
        rows: rows,
        pending: pending,
        allowQuarantined: allowQuarantined,
      ),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final row = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: AppSpacing.xs),
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('source_field'),
            borderRadius: BorderRadius.circular(AppRadius.control),
            onTap: () => _open(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceWell,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: row == null
                  ? const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Choisir un lot et son emplacement',
                            style: AppTypography.body,
                          ),
                        ),
                        Icon(Icons.search, color: AppColors.textSecondary),
                      ],
                    )
                  : _RowSummary(row: row, pending: pending),
            ),
          ),
        ),
      ],
    );
  }
}

class _RowSummary extends StatelessWidget {
  final StockLevelData row;
  final PendingStockDelta pending;
  const _RowSummary({required this.row, required this.pending});

  @override
  Widget build(BuildContext context) {
    final delta = pending.forPair(row.batchId, row.locationId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(AppRadius.control),
                boxShadow: AppShadows.card,
              ),
              child: Icon(
                row.expiryDate != null
                    ? Icons.medication_outlined
                    : Icons.inventory_2_outlined,
                size: 22,
                color: AppColors.navyHeader,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (row.reference.isNotEmpty)
                    Text(
                      'RÉF. ${row.reference}',
                      style: AppTypography.eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    row.productName,
                    style: AppTypography.bodyStrong,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lot ${row.batchNumber ?? '—'} · ${row.locationName}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${row.qty} ${row.unit}',
              style: AppTypography.metric.copyWith(
                fontSize: 17,
                color: AppColors.brandPrimary,
              ),
            ),
          ],
        ),
        if (delta != 0) ...[
          const SizedBox(height: 4),
          Text(
            delta < 0
                ? '$delta en attente d\'envoi (non inclus dans ${row.qty})'
                : '+$delta en attente d\'envoi (non inclus dans ${row.qty})',
            key: const ValueKey('pending_delta'),
            style: AppTypography.caption.copyWith(color: AppColors.warningText),
          ),
        ],
        _StatusBadges(row: row),
      ],
    );
  }
}

class _StatusBadges extends StatelessWidget {
  final StockLevelData row;
  const _StatusBadges({required this.row});

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (row.isQuarantined)
        const TypeBadge(label: 'Quarantaine', tone: BadgeTone.red),
      if (row.isExpired)
        const TypeBadge(label: 'Périmé', tone: BadgeTone.red)
      else if (row.isNearExpiry && row.expiryDate != null)
        TypeBadge(
          label: 'DLC ${DateFormat('dd/MM/yy').format(row.expiryDate!)}',
          tone: BadgeTone.orange,
        )
      else if (row.expiryDate != null)
        TypeBadge(
          label: 'DLC ${DateFormat('dd/MM/yy').format(row.expiryDate!)}',
          tone: BadgeTone.green,
        ),
      if (row.locationArchived)
        const TypeBadge(label: 'Emplacement archivé', tone: BadgeTone.gray),
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: badges),
    );
  }
}

class _SourceSheet extends StatefulWidget {
  final List<StockLevelData> rows;
  final PendingStockDelta pending;
  final bool allowQuarantined;
  const _SourceSheet({
    required this.rows,
    required this.pending,
    required this.allowQuarantined,
  });

  @override
  State<_SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<_SourceSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final shown = StockRules.sorted(
      widget.rows.where((r) => StockRules.matches(r, _query)),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lot et emplacement', style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('source_search'),
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Produit, référence, lot ou emplacement',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: shown.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun lot en stock ne correspond.',
                          style: AppTypography.caption,
                        ),
                      )
                    : ListView.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final row = shown[i];
                          final blocked =
                              row.isQuarantined && !widget.allowQuarantined;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey('source_${row.id}'),
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              onTap: blocked
                                  ? null
                                  : () => Navigator.of(context).pop(row),
                              child: Opacity(
                                opacity: blocked ? 0.55 : 1,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundCard,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.card),
                                    border: Border.all(
                                      color: AppColors.hairline,
                                    ),
                                    boxShadow: AppShadows.card,
                                  ),
                                  child: _RowSummary(
                                    row: row,
                                    pending: widget.pending,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
