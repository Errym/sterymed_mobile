import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class ListTileSkeleton extends StatelessWidget {
  final int lines;
  const ListTileSkeleton({super.key, this.lines = 2});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundSubtle,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 14,
            width: 160,
            decoration: BoxDecoration(
              color: AppColors.backgroundMuted,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          for (var i = 0; i < lines - 1; i++) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              height: 12,
              width: i.isEven ? 220 : 180,
              decoration: BoxDecoration(
                color: AppColors.backgroundMuted,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  final int count;
  const ListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const ListTileSkeleton(),
    );
  }
}
