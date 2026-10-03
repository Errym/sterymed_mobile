part of '../settings_screen.dart';

class _HubRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  const _HubRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('hub-$route'),
      onTap: () => context.openRoute(route),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Row(
        children: [
          EntityMark.icon(icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyStrong),
                Text(subtitle, style: AppTypography.caption),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// Is the phone's work safely on the server? Online or not, how many entries
/// still wait to be sent, and whether any needs a person's attention.
class _SyncSection extends StatelessWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<SyncStatusCubit>()) return const SizedBox.shrink();
    return BlocBuilder<SyncStatusCubit, SyncStatus>(
      bloc: getIt<SyncStatusCubit>(),
      builder: (context, s) {
        final needsYou = s.manualReviewCount + s.quarantinedCount;
        final (label, tone, icon) = !s.online
            ? ('Hors ligne', StatusTone.warning, Icons.cloud_off_outlined)
            : needsYou > 0
            ? ('À vérifier', StatusTone.danger, Icons.error_outline)
            : s.pendingCount > 0
            ? ('En cours d\'envoi', StatusTone.info, Icons.sync)
            : ('À jour', StatusTone.success, Icons.cloud_done_outlined);
        return _Section(
          title: 'Synchronisation',
          children: [
            InkWell(
              key: const Key('settings-sync'),
              onTap: () => context.openRoute(Routes.sync),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Row(
                children: [
                  EntityMark.icon(icon),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Données du cabinet',
                          style: AppTypography.bodyStrong,
                        ),
                        Text(
                          s.pendingCount == 0 && needsYou == 0
                              ? 'Rien en attente d\'envoi.'
                              : [
                                  if (s.pendingCount > 0)
                                    '${s.pendingCount} en attente',
                                  if (needsYou > 0) '$needsYou à vérifier',
                                ].join(' · '),
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(label: label, tone: tone),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Alert notifications on this phone. Every state says what is true: the
/// build may not carry Firebase settings, the phone may refuse them, or the
/// person may simply have them off.
class _PushSection extends StatelessWidget {
  const _PushSection();

  static const _note = 'Les alertes (stock bas, péremption, cycle en échec) '
      'restent toujours visibles dans l\'onglet Alertes.';

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<PushService>()) {
      return const _Section(
        title: 'Notifications',
        children: [_PushNote(_note, key: Key('alerts-in-app-only'))],
      );
    }
    final service = getIt<PushService>();
    return BlocBuilder<PushService, PushState>(
      bloc: service,
      builder: (context, s) {
        return _Section(
          title: 'Notifications',
          children: switch (s.availability) {
            PushAvailability.notConfigured => const [
                _PushNote(
                  'Les notifications ne sont pas activées dans cette version '
                  'de l\'application. $_note',
                  key: Key('alerts-in-app-only'),
                ),
              ],
            PushAvailability.blocked => [
                const _PushNote(
                  'Ce téléphone refuse les notifications de SteryMed. '
                  'Autorisez-les dans les réglages du téléphone pour être '
                  'prévenu d\'une alerte.',
                  key: Key('push-blocked'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('push-open-settings'),
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Ouvrir les réglages'),
                  ),
                ),
              ],
            PushAvailability.off || PushAvailability.on => [
                SwitchListTile(
                  key: const Key('push-switch'),
                  contentPadding: EdgeInsets.zero,
                  value: s.availability == PushAvailability.on,
                  onChanged: s.busy
                      ? null
                      : (on) => on ? service.enable() : service.disable(),
                  title: const Text(
                    'Alertes sur ce téléphone',
                    style: AppTypography.bodyStrong,
                  ),
                  subtitle: const Text(
                    'Un message vous prévient quand une alerte apparaît. Il '
                    'ne contient aucune donnée patient ni nom de produit.',
                    style: AppTypography.caption,
                  ),
                ),
                if (s.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      s.error!,
                      key: const Key('push-error'),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.danger),
                    ),
                  ),
              ],
          },
        );
      },
    );
  }
}

class _PushNote extends StatelessWidget {
  final String text;
  const _PushNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.notifications_none,
          size: 18,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppTypography.caption)),
      ],
    );
  }
}
