part of '../dashboard_screen.dart';

class _AttentionTile extends StatelessWidget {
  final DashboardAttentionItem item;
  const _AttentionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = switch (item.severity) {
      'critical' => (
          AppColors.danger,
          AppColors.dangerLight,
          Icons.error_outline
        ),
      'warning' => (
          AppColors.warning,
          AppColors.warningLight,
          Icons.warning_amber_outlined
        ),
      _ => (AppColors.info, AppColors.infoLight, Icons.info_outline),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.openRoute(item.route),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.hairline),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: fg,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.md),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration:
                              BoxDecoration(color: bg, shape: BoxShape.circle),
                          child: Icon(icon, color: fg, size: 16),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child:
                              Text(item.label, style: AppTypography.bodyStrong),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textTertiary, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Today's cycles
// ─────────────────────────────────────────────────────────────────────────

class _TodayCyclesSection extends StatelessWidget {
  final List<DashboardTodayCycle> cycles;
  final bool unavailable;
  const _TodayCyclesSection({required this.cycles, this.unavailable = false});

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
              const Expanded(
                child:
                    Text('Cycles du jour', style: AppTypography.sectionTitle),
              ),
              TextButton(
                onPressed: () => context.openRoute(Routes.cycles),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          if (unavailable)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: _UnavailableTile(
                key: Key('dashboard-cycles-unavailable'),
                message: 'Cycles indisponibles. Tirez pour actualiser.',
              ),
            )
          else if (cycles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Row(
                children: [
                  const Icon(Icons.event_available_outlined,
                      color: AppColors.textTertiary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Aucun cycle aujourd\'hui.',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final c in cycles)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: InkWell(
                  onTap: () => context.openRoute(Routes.cyclesDetail(c.id)),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cycle ${c.number}',
                                  style: AppTypography.bodyStrong),
                              const SizedBox(height: 2),
                              Text(c.deviceName, style: AppTypography.caption),
                            ],
                          ),
                        ),
                        _statusBadge(c.status),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'released':
        return const TypeBadge(label: 'Libéré', tone: BadgeTone.green);
      case 'in_progress':
        return const TypeBadge(label: 'En cours', tone: BadgeTone.blue);
      case 'awaiting_release':
        return const TypeBadge(
            label: 'Contrôles saisis', tone: BadgeTone.yellow);
      case 'rejected':
        return const TypeBadge(label: 'Rejeté', tone: BadgeTone.red);
      case 'completed':
        return const TypeBadge(label: 'Terminé', tone: BadgeTone.orange);
      default:
        return const TypeBadge(label: 'Créé', tone: BadgeTone.gray);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Quick access / governance menu
// ─────────────────────────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  final List<DashboardRecentProcedure> items;
  const _ActivitySection({required this.items});

  /// "à l'instant", "il y a 12 min", "il y a 3 h", else the date.
  static String _when(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '•';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Activité récente', style: AppTypography.sectionTitle),
            ),
            TextButton.icon(
              onPressed: () => context.openRoute(Routes.audit),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right, size: 16),
              label: const Text('Voir tout'),
            ),
          ],
        ),
        for (final e in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              onTap: () => context.openRoute(Routes.audit),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.brandPrimaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _initials(e.actor),
                      style: AppTypography.bodyStrong.copyWith(
                        color: AppColors.brandPrimaryDark,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.label,
                          style: AppTypography.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (e.actor.isNotEmpty) e.actor,
                            _when(e.usedAt),
                          ].where((s) => s.isNotEmpty).join('  ·  '),
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
            ),
          ),
      ],
    );
  }
}
