import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import 'app_image.dart';

class AttachmentTile extends StatelessWidget {
  final String url;
  final String? fileName;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const AttachmentTile({
    super.key,
    required this.url,
    this.fileName,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AppImage(
                  url: url,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              if (onDelete != null)
                Positioned(
                  top: 4,
                  right: 4,
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
          ),
        ),
      ),
    );
  }
}
