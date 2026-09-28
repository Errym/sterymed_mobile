import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/cycle_attachment_data.dart';

/// Simple 90x90 placeholder tile shown inline on the cycle detail screen —
/// no image/PDF preview loading. Distinct from the tiles inside
/// [CycleAttachmentGrid] (used on the dedicated cycle attachments screen,
/// which does load previews via [MediaUrl]).
class CycleDetailAttachmentTile extends StatelessWidget {
  final CycleAttachmentData a;
  final VoidCallback? onDelete;

  const CycleDetailAttachmentTile({super.key, required this.a, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.image_outlined,
                color: AppColors.textSecondary, size: 24),
          ),
          if (onDelete != null)
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: AppColors.backgroundCard,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: AppColors.danger),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
