import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
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

class _BlockedView extends StatefulWidget {
  const _BlockedView();

  @override
  State<_BlockedView> createState() => _BlockedViewState();
}

class _BlockedViewState extends State<_BlockedView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Étiquette bloquée'),
        backgroundColor: AppColors.dangerLight,
        foregroundColor: AppColors.danger,
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<LabelDetailBloc, LabelDetailState>(
        builder: (context, state) {
          if (state.status == LabelDetailStatus.failure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.error ?? 'Impossible de charger l\'étiquette.',
                      style: AppTypography.body,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'Nouveau scan',
                      icon: Icons.qr_code_scanner,
                      onPressed: () => context.go(Routes.scanner),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state.status != LabelDetailStatus.success ||
              state.result == null) {
            return const LoadingView();
          }

          final r = state.result!;
          final isExpired = r.status.name == 'expired';
          final isRecalled = r.status.name == 'recalled';

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                ScaleTransition(
                  scale: _scale,
                  child: Container(
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
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isExpired
                                ? Icons.timer_off_outlined
                                : isRecalled
                                    ? Icons.report_gmailerrorred_outlined
                                    : Icons.block,
                            size: 44,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          isExpired
                              ? 'Étiquette expirée'
                              : isRecalled
                                  ? 'Étiquette rappelée'
                                  : 'Étiquette bloquée',
                          style: AppTypography.sectionTitle
                              .copyWith(color: AppColors.danger),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          r.reason ??
                              'Cette étiquette ne peut pas être utilisée. '
                                  'Contactez le responsable de la stérilisation.',
                          style: AppTypography.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Nouveau scan',
                  icon: Icons.qr_code_scanner,
                  onPressed: () => context.go(Routes.scanner),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          );
        },
      ),
    );
  }
}
