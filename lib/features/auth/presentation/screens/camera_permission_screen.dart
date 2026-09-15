import 'package:flutter/material.dart';

import '../../../../core/permissions/camera_permission.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';

class CameraPermissionScreen extends StatelessWidget {
  const CameraPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(
        title: const Text('Autorisation caméra'),
        backgroundColor: AppColors.backgroundApp,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xxl),
            const Icon(
              Icons.camera_alt_outlined,
              size: 72,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Accès à la caméra',
              textAlign: TextAlign.center,
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'SteryMed utilise la caméra pour scanner les étiquettes QR et '
              'DataMatrix de vos instruments et suivre leur traçabilité.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Autoriser la caméra',
              icon: Icons.camera_alt_outlined,
              onPressed: () async {
                final granted = await CameraPermission.request();
                if (!context.mounted) return;
                if (granted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Ouvrir les paramètres',
              onPressed: () => CameraPermission.openSettings(),
            ),
          ],
        ),
      ),
    );
  }
}
