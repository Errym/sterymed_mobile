part of '../product_list_screen.dart';

class _ProductTile extends StatelessWidget {
  final ProductData product;
  final String? family;
  final int? stock;
  final bool low;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.family,
    required this.stock,
    required this.low,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final eyebrow = [
      if (product.reference.isNotEmpty) product.reference,
      if (product.barcode != null && product.barcode!.isNotEmpty)
        product.barcode!,
    ].join('  ·  ');
    final empty = stock != null && stock == 0;
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
                child: Icon(
                  product.isSterilizable
                      ? Icons.sanitizer_outlined
                      : Icons.inventory_2_outlined,
                  size: 21,
                  color: AppColors.navyHeader,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow.isNotEmpty)
                      Text(
                        eyebrow,
                        style: AppTypography.eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      style: AppTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (stock != null) ...[
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(
                  label: empty
                      ? 'Rupture'
                      : low
                          ? 'Stock bas'
                          : 'Stock OK',
                  tone: empty || low ? StatusTone.danger : StatusTone.success,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (family != null && family!.isNotEmpty)
                InfoTag(family!, icon: Icons.folder_outlined),
              InfoTag(
                'Unité : ${product.unit}',
                icon: Icons.straighten_outlined,
              ),
              if (product.minThreshold > 0)
                InfoTag(
                  'Seuil ${product.minThreshold} ${product.unit}',
                  icon: Icons.flag_outlined,
                ),
              if (product.isSterilizable)
                const InfoTag(
                  'Stérilisable',
                  icon: Icons.verified_outlined,
                  color: AppColors.success,
                ),
            ],
          ),
          if (stock != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$stock',
                  style: AppTypography.metric.copyWith(
                    fontSize: 22,
                    color: empty || low ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${product.unit} en stock',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A product in full: identity, thresholds, where it is stored and how much,
/// and (for those who manage the catalogue) edit and delete.
class _ProductSheet extends StatelessWidget {
  final ProductData product;
  final String? family;
  final List<StockLevelData> levels;
  final bool canManage;
  final ProductListBloc bloc;

  /// The catalogue screen's own context: the sheet's context is gone once the
  /// sheet closes, and it has no [ProductListBloc] above it anyway.
  final BuildContext parentContext;

  const _ProductSheet({
    required this.product,
    required this.family,
    required this.levels,
    required this.canManage,
    required this.bloc,
    required this.parentContext,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductData product,
    required String? family,
    required List<StockLevelData> levels,
    required bool canManage,
    required ProductListBloc bloc,
  }) {
    final parentContext = context;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _ProductSheet(
        product: product,
        family: family,
        levels: levels,
        canManage: canManage,
        bloc: bloc,
        parentContext: parentContext,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = levels.fold<int>(0, (s, l) => s + l.qty);
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
            Text(
              product.reference.isEmpty
                  ? 'PRODUIT'
                  : 'RÉF. ${product.reference}',
              style: AppTypography.eyebrow,
            ),
            const SizedBox(height: 2),
            Text(product.name, style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.lg),
            FormCard(
              title: 'Fiche produit',
              gap: AppSpacing.xs,
              children: [
                _Row(Icons.tag, 'Référence',
                    product.reference.isEmpty ? '—' : product.reference),
                _Row(Icons.qr_code_2, 'Code-barres',
                    (product.barcode ?? '').isEmpty ? '—' : product.barcode!),
                _Row(Icons.folder_outlined, 'Famille', family ?? '—'),
                _Row(Icons.straighten_outlined, 'Unité', product.unit),
                _Row(
                  Icons.verified_outlined,
                  'Stérilisable',
                  product.isSterilizable ? 'Oui' : 'Non',
                  color: product.isSterilizable ? AppColors.success : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FormCard(
              title: 'Stock',
              gap: AppSpacing.xs,
              children: [
                _Row(Icons.flag_outlined, 'Seuil minimum',
                    '${product.minThreshold} ${product.unit}'),
                _Row(
                  Icons.inventory_2_outlined,
                  'Stock total',
                  '$total ${product.unit}',
                  color: product.minThreshold > 0 && total <= product.minThreshold
                      ? AppColors.danger
                      : null,
                ),
                if (levels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Aucun stock pour ce produit actuellement.',
                      style: AppTypography.caption,
                    ),
                  )
                else
                  for (final l in levels.where((l) => l.qty > 0))
                    _Row(
                      Icons.place_outlined,
                      l.batchNumber == null
                          ? l.locationName
                          : '${l.locationName} · lot ${l.batchNumber}',
                      '${l.qty} ${l.unit}',
                    ),
              ],
            ),
            if (canManage) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (parentContext.mounted) {
                          ProductFormSheet.show(parentContext, existing: product);
                        }
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Modifier'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: () async {
                        final ok = await ConfirmationDialog.show(
                          context,
                          title: 'Supprimer le produit ?',
                          message: product.name,
                          confirmLabel: 'Supprimer',
                          isDestructive: true,
                        );
                        if (ok && context.mounted) {
                          Navigator.of(context).pop();
                          bloc.add(DeleteProduct(product.id));
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Supprimer'),
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
