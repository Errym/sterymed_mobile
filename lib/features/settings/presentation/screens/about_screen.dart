import 'package:flutter/material.dart';

import '../../../../core/config/build_info.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/misc/app_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'À propos'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          AnimatedListItem(
            index: 0,
            child: Column(
              children: [
                const AppLogo(height: 56),
                const SizedBox(height: AppSpacing.xl),
                const Text(
                  'SteryMed',
                  textAlign: TextAlign.center,
                  style: AppTypography.pageTitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Traçabilité et conformité de la stérilisation',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AnimatedListItem(
            index: 1,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _Row(label: 'Version', value: BuildInfo.fullVersion),
                  const Divider(
                      height: AppSpacing.lg, color: AppColors.borderLight),
                  const _Row(label: 'Environnement', value: Env.environment),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AnimatedListItem(
            index: 2,
            child: Text(
              'Conçu pour les cabinets dentaires français. '
              'Les données sont chiffrées et l\'audit est immuable.',
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTypography.label)),
        Text(value, style: AppTypography.bodyStrong),
      ],
    );
  }
}
