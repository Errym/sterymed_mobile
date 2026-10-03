part of '../prosthetic_laboratories_screen.dart';

/// One partner laboratory in the list: identity, contact buttons, and how
/// much work it holds right now (counted by the server, loaded lazily).
class _LabCard extends StatelessWidget {
  final LaboratoryData lab;
  final Future<LaboratoryStats> stats;
  final VoidCallback onTap;

  const _LabCard({required this.lab, required this.stats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasContact = (lab.contactPhone ?? '').isNotEmpty ||
        (lab.contactEmail ?? '').isNotEmpty ||
        (lab.address ?? '').isNotEmpty;
    return AppCard(
      key: Key('lab-${lab.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EntityMark.initials(EntityMark.initialsOf(lab.name)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lab.name, style: AppTypography.cardTitle),
                    if ((lab.contactName ?? '').isNotEmpty)
                      Text(
                        lab.contactName!,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabStatsStrip(stats: stats),
          if (hasContact) ...[
            const SizedBox(height: AppSpacing.sm),
            ContactActions(
              phone: lab.contactPhone,
              email: lab.contactEmail,
              address: lab.address,
            ),
          ],
        ],
      ),
    );
  }
}

/// "2 chez le laboratoire · 1 à poser": never a made-up zero. While loading it
/// says so; if the server cannot be asked it says that instead.
class _LabStatsStrip extends StatelessWidget {
  final Future<LaboratoryStats> stats;
  const _LabStatsStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LaboratoryStats>(
      future: stats,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Text('Travaux en cours…', style: AppTypography.caption);
        }
        if (snap.hasError || !snap.hasData) {
          return const Text(
            'Travaux indisponibles',
            key: Key('lab-stats-unavailable'),
            style: AppTypography.caption,
          );
        }
        final s = snap.data!;
        if (s.atLaboratory == 0 && s.waitingForPlacement == 0) {
          return const Wrap(
            spacing: AppSpacing.xs,
            children: [
              InfoTag(
                'Aucun travail en cours',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
            ],
          );
        }
        return Wrap(
          key: const Key('lab-stats'),
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            if (s.atLaboratory > 0)
              InfoTag(
                '${s.atLaboratory} chez le laboratoire',
                icon: Icons.local_shipping_outlined,
              ),
            if (s.waitingForPlacement > 0)
              InfoTag(
                s.hasUrgent
                    ? '${s.waitingForPlacement} à poser · ${s.urgent} en retard'
                    : '${s.waitingForPlacement} à poser',
                icon: Icons.hourglass_bottom,
                color: s.hasUrgent ? AppColors.danger : AppColors.warningText,
              ),
          ],
        );
      },
    );
  }
}
