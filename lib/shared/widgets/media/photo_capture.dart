import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class PhotoCapture extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const PhotoCapture({
    super.key,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.borderMedium,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.add_a_photo_outlined,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Ajouter une photo', style: AppTypography.bodyStrong),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Appareil'),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Galerie'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
