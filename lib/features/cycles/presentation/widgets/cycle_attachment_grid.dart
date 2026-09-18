import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/media_url.dart';
import '../../data/models/cycle_attachment_data.dart';

class CycleAttachmentGrid extends StatelessWidget {
  final List<CycleAttachmentData> attachments;
  final VoidCallback? onAdd;
  final void Function(CycleAttachmentData)? onDelete;

  const CycleAttachmentGrid({
    super.key,
    required this.attachments,
    this.onAdd,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final a in attachments)
          SizedBox(
            width: 100,
            height: 100,
            child: _AttachmentTile(
              attachment: a,
              onDelete: onDelete == null ? null : () => onDelete!(a),
            ),
          ),
        if (onAdd != null)
          SizedBox(
            width: 100,
            height: 100,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderMedium),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final CycleAttachmentData attachment;
  final VoidCallback? onDelete;

  const _AttachmentTile({required this.attachment, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: _preview(),
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
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _preview() {
    if (attachment.url.isEmpty) {
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textTertiary,
          size: 24,
        ),
      );
    }

    // Resolve the URL — handles the minio:9000 -> localhost:9000 rewrite.
    final resolvedUrl = MediaUrl.resolve(attachment.url);

    if (attachment.isImage) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: AppColors.textTertiary,
            size: 24,
          ),
        ),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }

    if (attachment.isPdf) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.danger,
              size: 32,
            ),
            SizedBox(height: 4),
            Text(
              'PDF',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: Icon(
        Icons.insert_drive_file_outlined,
        color: AppColors.textSecondary,
        size: 32,
      ),
    );
  }
}
