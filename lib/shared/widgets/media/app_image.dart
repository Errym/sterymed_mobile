import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AppImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: AppColors.backgroundMuted,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: AppColors.backgroundMuted,
        child: const Icon(
          Icons.broken_image_outlined,
          color: AppColors.textTertiary,
        ),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
