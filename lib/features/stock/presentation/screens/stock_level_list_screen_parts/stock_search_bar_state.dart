part of '../stock_level_list_screen.dart';

class _StockSearchBarState extends State<_StockSearchBar> {
  final _controller = TextEditingController();

  @override
  void didUpdateWidget(covariant _StockSearchBar old) {
    super.didUpdateWidget(old);
    if (widget.query.isEmpty && _controller.text.isNotEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.control),
        boxShadow: AppShadows.card,
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: AppTypography.body,
        decoration: InputDecoration(
          hintText: 'Rechercher un produit, réf ou lot...',
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textSecondary,
          ),
          suffixIcon: IconButton(
            key: const Key('stock-scan-product'),
            tooltip: 'Scanner un code-barres',
            icon: const Icon(
              Icons.barcode_reader,
              color: AppColors.navyHeader,
            ),
            onPressed: widget.onScan,
          ),
        ),
      ),
    );
  }
}

class _StockMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _StockMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTypography.eyebrow,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AppTypography.metric.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: color),
          ),
        ],
      ),
    );
  }
}

/// What opens when a stock row is tapped: everything the server knows about
/// that line, and the movements the signed-in role may start from it.
class _StockDetailSheet extends StatelessWidget {
  final StockLevelData level;
  final bool canManage;
  const _StockDetailSheet({required this.level, required this.canManage});

  static Future<void> show(BuildContext context, StockLevelData level) {
    final canManage = getIt<SessionStore>().hasPermission('inventory.manage');
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _StockDetailSheet(level: level, canManage: canManage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = stockStatusOf(level);
    final canMove = canManage && level.batchId != null;
    final eyebrow = [
      level.reference,
      if (level.batchNumber != null) 'LOT ${level.batchNumber}',
    ].where((s) => s.isNotEmpty).join('  ·  ');
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
                      if (eyebrow.isNotEmpty)
                        Text(eyebrow, style: AppTypography.eyebrow),
                      const SizedBox(height: 2),
                      Text(level.productName, style: AppTypography.sectionTitle),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge(label: status.label, tone: status.tone),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${level.qty}',
                  style: AppTypography.kpiNumber.copyWith(
                    fontSize: 34,
                    color: level.isLow || level.isExpired
                        ? status.color
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    level.minThreshold > 0
                        ? '${level.unit}  /  min. ${level.minThreshold}'
                        : level.unit,
                    style: AppTypography.body,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: stockGaugeOf(level),
                minHeight: 6,
                backgroundColor: AppColors.backgroundMuted,
                valueColor: AlwaysStoppedAnimation<Color>(status.color),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FormCard(
              gap: AppSpacing.xs,
              children: [
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: 'Emplacement',
                  value: level.locationName,
                ),
                if (level.batchNumber != null)
                  _DetailRow(
                    icon: Icons.qr_code_2,
                    label: 'Lot',
                    value: level.batchNumber!,
                  ),
                if (level.expiryDate != null)
                  _DetailRow(
                    icon: Icons.event_busy_outlined,
                    label: level.isExpired ? 'Périmé depuis le' : 'Expire le',
                    value: AppDateFormatter.date(level.expiryDate!),
                    color: level.isExpired
                        ? AppColors.danger
                        : level.isNearExpiry
                            ? AppColors.warning
                            : null,
                  ),
                _DetailRow(
                  icon: Icons.tag,
                  label: 'Référence',
                  value: level.reference.isEmpty ? '—' : level.reference,
                ),
                if (level.isQuarantined)
                  const _DetailRow(
                    icon: Icons.block_outlined,
                    label: 'Statut du lot',
                    value: 'En quarantaine',
                    color: AppColors.danger,
                  ),
              ],
            ),
            if (canMove) ...[
              const SizedBox(height: AppSpacing.lg),
              const Text('ACTIONS SUR CETTE LIGNE', style: AppTypography.eyebrow),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (level.qty > 0 && !level.isQuarantined) ...[
                    Expanded(
                      child: _SheetAction(
                        icon: Icons.remove_circle_outline,
                        label: 'Sortie',
                        onTap: () => _go(
                          context,
                          Routes.stockIssueFor(
                            level.batchId!,
                            locationId: level.locationId,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (level.qty > 0) ...[
                    Expanded(
                      child: _SheetAction(
                        icon: Icons.swap_horiz,
                        label: 'Transfert',
                        onTap: () => _go(
                          context,
                          Routes.stockTransferFor(
                            level.batchId!,
                            locationId: level.locationId,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: _SheetAction(
                      icon: Icons.edit_outlined,
                      label: 'Ajuster',
                      onTap: () => _go(
                        context,
                        Routes.stockAdjustFor(
                          level.batchId!,
                          locationId: level.locationId,
                        ),
                      ),
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

  void _go(BuildContext context, String route) => _closeThenOpen(context, route);
}

/// Closes the bottom sheet, then opens [route] the way a person expects
/// (a form is pushed on top of the stock tab). The router is taken *before*
/// the sheet closes: its own context is gone afterwards.
void _closeThenOpen(BuildContext sheetContext, String route) {
  final router = GoRouter.of(sheetContext);
  Navigator.of(sheetContext).pop();
  if (isTabRoute(route)) {
    router.go(route);
  } else {
    router.push(route);
  }
}
