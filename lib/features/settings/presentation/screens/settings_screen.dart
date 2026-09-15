import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Paramètres'),
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
              Icon(Icons.settings_outlined,
                  size: 64, color: AppColors.textTertiary),
              SizedBox(height: AppSpacing.md),
              Text('Paramètres à venir', style: AppTypography.sectionTitle),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Les paramètres du cabinet et de votre compte seront disponibles ici.',
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
