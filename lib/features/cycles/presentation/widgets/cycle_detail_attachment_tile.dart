import 'package:flutter/material.dart';

import '../../../../core/utils/media_url.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/cycle_attachment_data.dart';

/// Simple 90x90 placeholder tile shown inline on the cycle detail screen —
/// no image/PDF preview loading. Distinct from the tiles inside
/// [CycleAttachmentGrid] (used on the dedicated cycle attachments screen,
/// which does load previews via [MediaUrl]).
class CycleDetailAttachmentTile extends StatelessWidget {
  final CycleAttachmentData a;
  final VoidCallback? onDelete;
  final VoidCallback? onOpen;

  const CycleDetailAttachmentTile({
    super.key,
    required this.a,
    this.onDelete,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: onOpen,
              child: a.isImage && a.url.isNotEmpty
                  ? Image.network(
                      MediaUrl.resolve(a.url),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textSecondary,
                          size: 24,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        a.isPdf
                            ? Icons.picture_as_pdf_outlined
                            : Icons.insert_drive_file_outlined,
                        color: a.isPdf
                            ? AppColors.danger
                            : AppColors.textSecondary,
                        size: 24,
                      ),
                    ),
            ),
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
