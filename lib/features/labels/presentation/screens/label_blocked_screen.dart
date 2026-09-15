import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../bloc/label_detail_bloc.dart';

class LabelBlockedScreen extends StatelessWidget {
  final String code;
  const LabelBlockedScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => LabelDetailBloc(ctx.read())..add(LoadLabel(code)),
      child: const _BlockedView(),
    );
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Étiquette bloquée')),
      body: BlocBuilder<LabelDetailBloc, LabelDetailState>(
        builder: (context, state) {
          if (state.status != LabelDetailStatus.success ||
              state.result == null) {
            return const LoadingView();
          }
          final r = state.result!;
          final isExpired = r.status.name == 'expired';
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isExpired ? Icons.timer_off_outlined : Icons.block,
                        size: 56,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        isExpired ? 'Étiquette expirée' : 'Étiquette rappelée',
                        style: AppTypography.sectionTitle
                            .copyWith(color: AppColors.danger),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        r.reason ??
                            'Cette étiquette ne peut pas être utilisée. '
                                'Contactez le responsable.',
                        style: AppTypography.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
