part of '../batch_list_screen.dart';

/// "Où est ce lot ?": the places that hold it, read from the stock rows.
class _Where extends StatelessWidget {
  final BatchData batch;
  const _Where({required this.batch});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StockLevelData>>(
      future: getIt<StockRepository>().listLevels(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final rows = (snap.data ?? const <StockLevelData>[])
            .where((r) => r.batchId == batch.id && r.qty > 0)
            .toList();
        if (snap.hasError) {
          return const Text(
            'Les emplacements n\'ont pas pu être chargés.',
            style: AppTypography.caption,
          );
        }
        if (rows.isEmpty) {
          return const Text(
            'Ce lot n\'est présent dans aucun emplacement.',
            style: AppTypography.caption,
          );
        }
        return FormCard(
          title: 'Où est ce lot ?',
          gap: AppSpacing.xs,
          children: [
            for (final r in rows)
              _SheetRow(
                icon: Icons.place_outlined,
                label: r.locationName,
                value: '${r.qty} ${r.unit}',
              ),
          ],
        );
      },
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.label)),
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodyStrong.copyWith(color: color),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const _Action({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceWell,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: () {
          // The router is taken before the sheet closes: the sheet's own
          // context is gone afterwards.
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          if (isTabRoute(route)) {
            router.go(route);
          } else {
            router.push(route);
          }
        },
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: [
              Icon(icon, color: AppColors.navyHeader),
              const SizedBox(height: 4),
              Text(label, style: AppTypography.bodyStrong),
            ],
          ),
        ),
      ),
    );
  }
}
