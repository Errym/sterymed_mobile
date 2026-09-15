import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Scanner'),
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
              Icon(Icons.qr_code_scanner,
                  size: 64, color: AppColors.textTertiary),
              SizedBox(height: AppSpacing.md),
              Text(
                'Scanner à venir',
                style: AppTypography.sectionTitle,
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Le scanner QR / DataMatrix sera activé dans la prochaine phase.',
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
