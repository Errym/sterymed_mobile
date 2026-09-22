import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../data/models/cycle_release_data.dart';
import '../../data/repositories/cycle_repository.dart';
import '../widgets/release_decision_sheet.dart';

class CycleReleaseScreen extends StatelessWidget {
  final String cycleId;
  const CycleReleaseScreen({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Décision de libération'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 72,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Cycle prêt pour libération',
                  style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Prenez la décision de conformité pour ce cycle.',
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () async {
                  final result = await ReleaseDecisionSheet.show(context);
                  if (result == null || !context.mounted) return;

                  try {
                    final CycleReleaseData release =
                        await context.read<CycleRepository>().release(
                              cycleId,
                              decision: result.decision,
                              reason: result.reason,
                            );
                    if (!context.mounted) return;
                    AppSnackbar.show(
                      context,
                      'Décision enregistrée : ${release.decision.label}',
                      kind: SnackKind.success,
                    );
                    context.pop();
                  } catch (e) {
                    if (!context.mounted) return;
                    AppSnackbar.show(
                      context,
                      e.toString(),
                      kind: SnackKind.error,
                    );
                  }
                },
                icon: const Icon(Icons.verified),
                label: const Text('Prendre la décision'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
