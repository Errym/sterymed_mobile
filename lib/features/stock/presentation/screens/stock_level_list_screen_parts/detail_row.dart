part of '../stock_level_list_screen.dart';

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _DetailRow({
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

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceWell,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onTap,
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

/// "Nouveau mouvement de stock": what kind of movement, in the clinic's words.
class _MovementSheet extends StatelessWidget {
  const _MovementSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _MovementSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    void go(String route) => _closeThenOpen(context, route);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
            const Text('Nouveau mouvement', style: AppTypography.sectionTitle),
            const SizedBox(height: 2),
            const Text(
              'Chaque mouvement est tracé avec votre identifiant.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            _MovementTile(
              icon: Icons.remove_circle_outline,
              title: 'Sortie de stock',
              subtitle: 'Consommer ou retirer du stock',
              onTap: () => go(Routes.stockIssue),
            ),
            _MovementTile(
              icon: Icons.swap_horiz,
              title: 'Transfert',
              subtitle: 'Déplacer entre deux emplacements',
              onTap: () => go(Routes.stockTransfer),
            ),
            _MovementTile(
              icon: Icons.edit_outlined,
              title: 'Ajustement',
              subtitle: 'Corriger un écart : casse, perte, lot retrouvé',
              onTap: () => go(Routes.stockAdjust),
            ),
            _MovementTile(
              icon: Icons.fact_check_outlined,
              title: 'Inventaire',
              subtitle: 'Compter un emplacement',
              onTap: () => go(Routes.inventory),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MovementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.brandPrimaryLight,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Icon(icon, color: AppColors.brandPrimaryDark),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.cardTitle),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
