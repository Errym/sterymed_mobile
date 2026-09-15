import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';

class AppDatePicker extends StatelessWidget {
  final String? label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  const AppDatePicker({
    super.key,
    this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final formatted = value != null
        ? DateFormat('dd/MM/yyyy').format(value!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTypography.label),
          const SizedBox(height: AppSpacing.xs),
        ],
        InkWell(
          onTap: enabled ? () => _pick(context) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: hint ?? 'Sélectionner une date',
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            child: Text(
              formatted ?? hint ?? 'Sélectionner une date',
              style: AppTypography.body.copyWith(
                color: formatted != null
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
