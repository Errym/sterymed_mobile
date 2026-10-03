part of '../product_list_screen.dart';

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _Row(this.icon, this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.label)),
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodyStrong.copyWith(color: color),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
