import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../data/models/cycle_data.dart';
import 'cycle_status_badge.dart';

/// The five stages a cycle goes through, in order.
const cycleStages = ['Préparation', 'Stérilisation', 'Contrôles', 'Décision', 'Clôture'];

/// Which stage (0-4) a cycle status stands at.
int cycleStageOf(String status) => switch (status) {
      'created' => 0,
      'in_progress' => 1,
      'completed' => 2,
      'awaiting_release' => 3,
      'released' || 'rejected' => 4,
      _ => 0,
    };

/// "1 h 12", "45 min": how long a cycle ran (or has been running).
String cycleDuration(CycleData c, {DateTime? now}) {
  final start = c.startedAt;
  if (start == null) return '—';
  final end = c.completedAt ?? (now ?? DateTime.now());
  final d = end.difference(start);
  if (d.inMinutes < 1) return '< 1 min';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  final m = d.inMinutes % 60;
  return '${d.inHours} h${m == 0 ? '' : ' ${m.toString().padLeft(2, '0')}'}';
}

/// What this person should do next, in plain words.
String cycleNextStep(String status, {required bool canManage, required bool canRelease}) =>
    switch (status) {
      'created' => canManage
          ? 'Ajoutez les instruments du chargement, puis démarrez le cycle.'
          : 'Ce cycle est en préparation.',
      'in_progress' => canManage
          ? 'Le cycle tourne. Terminez-le quand l\'autoclave a fini.'
          : 'Le cycle est en cours dans l\'autoclave.',
      'completed' => canManage
          ? 'Saisissez les tests de contrôle pour pouvoir libérer le cycle.'
          : 'En attente de la saisie des tests de contrôle.',
      'awaiting_release' => canRelease
          ? 'Les contrôles sont saisis : à vous de libérer ou de rejeter ce cycle.'
          : 'En attente de la décision d\'un responsable de libération.',
      'released' => 'Cycle libéré : les étiquettes peuvent être émises.',
      'rejected' => 'Cycle rejeté : aucune étiquette ne peut être émise.',
      _ => '',
    };

class CycleHeaderCard extends StatelessWidget {
  final CycleData cycle;
  final bool canManage;
  final bool canRelease;

  /// Control tests recorded as failed on this cycle (0 when none is known).
  final int failedTests;

  const CycleHeaderCard({
    super.key,
    required this.cycle,
    required this.canManage,
    required this.canRelease,
    this.failedTests = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = cycle;
    final stage = cycleStageOf(c.status);
    final rejected = c.status == 'rejected';
    final next = cycleNextStep(c.status, canManage: canManage, canRelease: canRelease);
    final params = [
      if (c.programTemperatureCelsius != null) '${c.programTemperatureCelsius} °C',
      if (c.programPlateauMinutes != null) '${c.programPlateauMinutes} min',
    ].join(' · ');

    return AppCard(
      key: const Key('cycle-header'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (c.deviceName.isEmpty ? 'Appareil inconnu' : c.deviceName)
                          .toUpperCase(),
                      style: AppTypography.eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text('Cycle ${c.number}', style: AppTypography.pageTitle),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              CycleStatusBadge(status: c.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Stepper(stage: stage, rejected: rejected),
          if (next.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              key: const Key('cycle-next-step'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: rejected
                    ? AppColors.danger.withValues(alpha: 0.08)
                    : AppColors.surfaceWell,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    rejected ? Icons.block : Icons.arrow_forward,
                    size: 16,
                    color: rejected ? AppColors.danger : AppColors.brandPrimary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(next, style: AppTypography.body)),
                ],
              ),
            ),
          ],
          if (failedTests > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              key: const Key('cycle-failed-tests'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      failedTests == 1
                          ? '1 test de contrôle a échoué sur ce cycle.'
                          : '$failedTests tests de contrôle ont échoué sur ce cycle.',
                      style: AppTypography.bodyStrong
                          .copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Figure('Paramètres', params.isEmpty ? '—' : params),
              _Figure('Durée', cycleDuration(c)),
              _Figure('Opérateur', c.operatorName ?? '—'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  const _Figure(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTypography.eyebrow, maxLines: 1),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.bodyStrong,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int stage;
  final bool rejected;
  const _Stepper({required this.stage, required this.rejected});

  @override
  Widget build(BuildContext context) {
    final done = rejected ? AppColors.danger : AppColors.brandPrimary;
    return Column(
      key: const Key('cycle-stepper'),
      children: [
        Row(
          children: [
            for (var i = 0; i < cycleStages.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i <= stage ? done : AppColors.hairline,
                  ),
                ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= stage ? done : AppColors.backgroundCard,
                  border: Border.all(
                    color: i <= stage ? done : AppColors.hairline,
                    width: 2,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < cycleStages.length; i++)
              Expanded(
                child: Text(
                  i == 4 && rejected ? 'Rejeté' : cycleStages[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == cycleStages.length - 1
                          ? TextAlign.right
                          : TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    fontWeight: i == stage ? FontWeight.w700 : FontWeight.w400,
                    color: i == stage
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
