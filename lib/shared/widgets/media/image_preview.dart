import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class ImagePreviewDialog extends StatelessWidget {
  final String url;

  const ImagePreviewDialog({super.key, required this.url});

  static Future<void> show(BuildContext context, String url) {
    return showDialog(
      context: context,
      barrierColor: AppColors.overlayScrim,
      builder: (_) => ImagePreviewDialog(url: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: Stack(
        children: [
          InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: AppColors.backgroundCard,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
