part of '../alert_list_screen.dart';

class _Count extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Count(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: AppTypography.kpiNumber.copyWith(
                color: value == 0 ? AppColors.textTertiary : AppColors.text(color),
                fontSize: 22,
              ),
            ),
            Text(
              label,
              style: AppTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<AlertData> alerts;
  final Color color;
  final IconData icon;
  final bool canManage;
  final Set<String> resolving;

  const _Group({
    required this.title,
    required this.alerts,
    required this.color,
    required this.icon,
    required this.canManage,
    required this.resolving,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: AppTypography.sectionTitle.copyWith(color: AppColors.text(color)),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${alerts.length}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.text(color),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final alert in alerts)
          _AlertTile(
            alert: alert,
            color: color,
            resolving: resolving.contains(alert.id),
            // Hidden, not disabled, for roles that cannot resolve; and an
            // already-resolved alert has nothing left to resolve.
            onResolve: (!canManage || alert.resolved)
                ? null
                : () async {
                    final confirmed = await ConfirmationDialog.show(
                      context,
                      title: 'Résoudre l\'alerte ?',
                      message: 'Êtes-vous sûr de vouloir marquer cette '
                          'alerte comme résolue ?',
                      confirmLabel: 'Résoudre',
                    );
                    if (confirmed && context.mounted) {
                      context.read<AlertListBloc>().add(ResolveAlert(alert.id));
                    }
                  },
          ),
      ],
    );
  }
}

/// "il y a 25 min", "hier", "il y a 3 j": how long the alert has been waiting.
String alertAge(DateTime created, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(created);
  if (d.inMinutes < 1) return 'à l\'instant';
  if (d.inMinutes < 60) return 'il y a ${d.inMinutes} min';
  if (d.inHours < 24) return 'il y a ${d.inHours} h';
  if (d.inDays == 1) return 'hier';
  return 'il y a ${d.inDays} j';
}

/// Where an alert's subject can be looked at, or null when there is no screen.
({String label, IconData icon, String route})? alertTarget(AlertData a) {
  final id = a.subjectId;
  if (a.subjectType.endsWith('Cycle') && id != null) {
    return (
      label: 'Voir le cycle',
      icon: Icons.autorenew,
      route: Routes.cyclesDetail(id),
    );
  }
  switch (a.type) {
    case 'low_stock':
      return (
        label: 'Voir le stock',
        icon: Icons.inventory_2_outlined,
        route: Routes.stock,
      );
    case 'near_expiry':
    case 'expired':
      return (
        label: 'Voir les lots',
        icon: Icons.qr_code_2,
        route: Routes.batches,
      );
  }
  return null;
}

IconData _typeIcon(String type) => switch (type) {
      'low_stock' => Icons.inventory_2_outlined,
      'near_expiry' => Icons.hourglass_bottom,
      'expired' => Icons.event_busy_outlined,
      'failed_cycle' => Icons.sync_problem_outlined,
      _ => Icons.notifications_outlined,
    };

class _AlertTile extends StatelessWidget {
  final AlertData alert;
  final Color color;
  final bool resolving;
  final VoidCallback? onResolve;

  const _AlertTile({
    required this.alert,
    required this.color,
    required this.resolving,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final typeLabel = alertTypeLabels[alert.type] ?? 'Alerte';
    final target = alertTarget(alert);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadius.card),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        EntityMark.icon(
                          _typeIcon(alert.type),
                          background: color.withValues(alpha: 0.12),
                          foreground: color,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                typeLabel.toUpperCase(),
                                style: AppTypography.eyebrow,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                alertAge(alert.createdAt),
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        SeverityBadge(severity: alert.severity.name),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(alert.displayMessage, style: AppTypography.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      'Détectée le ${fmt.format(alert.createdAt)}',
                      style: AppTypography.caption,
                    ),
                    if (alert.resolved) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                          'Résolue',
                          if (alert.resolvedAt != null)
                            'le ${fmt.format(alert.resolvedAt!)}',
                          if (alert.resolvedByName != null)
                            'par ${alert.resolvedByName}',
                        ].join(' '),
                        key: Key('alert-resolved-${alert.id}'),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.success),
                      ),
                    ],
                    if (target != null || onResolve != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (target != null)
                            OutlinedButton.icon(
                              key: Key('alert-open-${alert.id}'),
                              onPressed: () => context.openRoute(target.route),
                              icon: Icon(target.icon, size: 16),
                              label: Text(target.label),
                            ),
                          if (onResolve != null)
                            resolving
                                ? const Padding(
                                    padding: EdgeInsets.all(AppSpacing.sm),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : TextButton(
                                    onPressed: onResolve,
                                    child: const Text('Marquer comme résolu'),
                                  ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
