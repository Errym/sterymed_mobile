import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/code_lookup.dart';
import '../../data/repositories/stock_repository.dart';

/// What a scanned or typed product barcode, reference or lot number is: the
/// product, its lots and where they are. A pure read; the movement buttons only
/// open the usual forms with the lot and place already chosen, and nothing is
/// sent until the user confirms there.
class CodeLookupScreen extends StatefulWidget {
  final String code;
  const CodeLookupScreen({super.key, required this.code});

  @override
  State<CodeLookupScreen> createState() => _CodeLookupScreenState();
}

class _CodeLookupScreenState extends State<CodeLookupScreen> {
  CodeLookup? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await getIt<StockRepository>().lookupCode(widget.code);
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorMessage.from(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Produit scanné'),
      body: _loading
          ? const LoadingView(message: 'Recherche...')
          : r == null
          ? ErrorView(message: _error ?? 'Erreur', onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.qr_code_scanner,
                        size: 20,
                        color: AppColors.navyHeader,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('CODE SCANNÉ', style: AppTypography.eyebrow),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Code : ${r.code}',
                          style: AppTypography.bodyStrong,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.products.length > 1)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'Ce numéro de lot existe pour plusieurs produits : '
                      'vérifiez le bon produit.',
                      style: AppTypography.caption,
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                for (final p in r.products) _ProductCard(product: p),
              ],
            ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final LookupProduct product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWell,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.navyHeader,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RÉF. ${product.reference}',
                        style: AppTypography.eyebrow,
                      ),
                      const SizedBox(height: 2),
                      Text(product.name, style: AppTypography.cardTitle),
                    ],
                  ),
                ),
                if (product.isLow)
                  const StatusBadge(
                    label: 'Stock faible',
                    tone: StatusTone.warning,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${product.qtyOnHand}',
                  style: AppTypography.kpiNumber.copyWith(
                    fontSize: 30,
                    color: product.isLow ? AppColors.warning : null,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${product.unit} en stock',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
            if (product.batches.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Aucun lot enregistré pour ce produit.',
                  style: AppTypography.caption,
                ),
              ),
            for (final b in product.batches) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWell,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: _BatchSection(batch: b, unit: product.unit),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BatchSection extends StatelessWidget {
  final LookupBatch batch;
  final String unit;
  const _BatchSection({required this.batch, required this.unit});

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission('inventory.manage');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Lot ${batch.batchNumber}'
                '${batch.expiryDate == null ? '' : ' · exp. ${AppDateFormatter.date(batch.expiryDate!)}'}',
                style: AppTypography.bodyStrong,
              ),
            ),
            if (batch.isQuarantined)
              const StatusBadge(label: 'Quarantaine', tone: StatusTone.danger)
            else if (batch.isExpired)
              const StatusBadge(label: 'Périmé', tone: StatusTone.danger),
          ],
        ),
        Text('${batch.qtyOnHand} $unit au total', style: AppTypography.caption),
        const SizedBox(height: AppSpacing.xs),
        if (batch.locations.isEmpty)
          const Text(
            'Aucun stock à un emplacement.',
            style: AppTypography.caption,
          ),
        for (final loc in batch.locations)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${loc.locationName}${loc.archived ? ' (archivé)' : ''}'
                    ' : ${loc.quantity}',
                    style: AppTypography.body,
                  ),
                ),
                if (canManage && loc.quantity > 0) ...[
                  // A quarantined batch cannot leave stock: the server refuses,
                  // so the only move offered is none at all.
                  if (!batch.isQuarantined) ...[
                    IconButton(
                      key: ValueKey('issue_${batch.id}_${loc.locationId}'),
                      tooltip: 'Sortie',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => context.push(
                        Routes.stockIssueFor(
                          batch.id,
                          locationId: loc.locationId,
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('transfer_${batch.id}_${loc.locationId}'),
                      tooltip: 'Transfert',
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: () => context.push(
                        Routes.stockTransferFor(
                          batch.id,
                          locationId: loc.locationId,
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    key: ValueKey('adjust_${batch.id}_${loc.locationId}'),
                    tooltip: 'Ajustement',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push(
                      Routes.stockAdjustFor(
                        batch.id,
                        locationId: loc.locationId,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
