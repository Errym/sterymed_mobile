import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/media/attachment_tile.dart';
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
            child: AttachmentTile(
              url: a.url,
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
                    border: Border.all(
                      color: AppColors.borderMedium,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.add_a_photo_outlined,
                        color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
