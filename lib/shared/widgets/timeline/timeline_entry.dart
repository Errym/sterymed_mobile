import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class TimelineEntry extends StatelessWidget {
  final String title;
  final String? subtitle;
  final DateTime? timestamp;
  final bool isFirst;
  final bool isLast;
  final Color color;

  const TimelineEntry({
    super.key,
    required this.title,
    this.subtitle,
    this.timestamp,
    this.isFirst = false,
    this.isLast = false,
    this.color = AppColors.brandPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.backgroundCard, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.borderLight),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyStrong),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppTypography.caption),
                  ],
                  if (timestamp != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _format(timestamp!),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _format(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}
