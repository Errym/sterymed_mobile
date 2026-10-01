import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../../core/router/routes.dart';
import '../../../core/storage/outbox/outbox_item.dart';
import '../../../core/storage/outbox/outbox_status.dart';
import '../../../core/storage/outbox/outbox_store.dart';
import '../../../core/theme/tokens.dart';
import '../../../di/di.dart';

/// Says, on the record itself, that the user has a change for it that the
/// server has not confirmed yet. The screen's data is the last confirmed
/// state; without this the user could believe a queued action already took
/// effect (or that a stuck one was never made).
///
/// [resourceKey] matches an item's key exactly (`cycle:<id>`); with
/// [matchPrefix] it matches every key that starts with it (`stock:`), for
/// list screens.
class PendingChangesBanner extends StatelessWidget {
  final String resourceKey;
  final bool matchPrefix;

  /// Test seam: resolve the store without the global service locator.
  final OutboxStore? store;

  const PendingChangesBanner({
    super.key,
    required this.resourceKey,
    this.matchPrefix = false,
    this.store,
  });

  bool _matches(OutboxItem item) {
    final key = item.resourceKey;
    if (key == null) return false;
    return matchPrefix ? key.startsWith(resourceKey) : key == resourceKey;
  }

  static bool _isWaiting(OutboxStatus s) =>
      s == OutboxStatus.pending ||
      s == OutboxStatus.syncing ||
      s == OutboxStatus.authBlocked;

  @override
  Widget build(BuildContext context) {
    final outbox =
        store ??
        (getIt.isRegistered<OutboxStore>() ? getIt<OutboxStore>() : null);
    // No local queue (not yet initialised): there is nothing to report.
    if (outbox == null) return const SizedBox.shrink();
    return StreamBuilder<BoxEvent>(
      stream: outbox.changes,
      builder: (context, _) {
        final items = outbox.all().where(_matches).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        final stuck = items.where((i) => !_isWaiting(i.status)).length;
        final waiting = items.length - stuck;
        final hasStuck = stuck > 0;

        final text = hasStuck
            ? (stuck == 1
                  ? 'Une modification n’a pas pu être confirmée. Appuyez pour la vérifier.'
                  : '$stuck modifications n’ont pas pu être confirmées. Appuyez pour les vérifier.')
            : (waiting == 1
                  ? 'Une modification est en attente d’envoi. Les données affichées ne l’incluent pas encore.'
                  : '$waiting modifications sont en attente d’envoi. Les données affichées ne les incluent pas encore.');

        final fg = hasStuck ? AppColors.danger : AppColors.warning;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Material(
            color: hasStuck ? AppColors.dangerLight : AppColors.warningLight,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () {
                if (GoRouter.maybeOf(context) != null) {
                  context.push(Routes.sync);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      hasStuck ? Icons.error_outline : Icons.schedule,
                      size: 18,
                      color: fg,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        text,
                        style: AppTypography.caption.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
