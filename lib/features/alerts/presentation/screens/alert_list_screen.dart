import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class AlertListScreen extends StatelessWidget {
  const AlertListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Alertes'),
        backgroundColor: AppColors.backgroundApp,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_outlined,
                  size: 64, color: AppColors.textTertiary),
              SizedBox(height: AppSpacing.md),
              Text('Alertes à venir', style: AppTypography.sectionTitle),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Les alertes apparaîtront ici.',
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
