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

  /// `showDatePicker` asserts when `initialDate` falls outside the allowed
  /// range, e.g. a "Du" field capped at a past "Au" date, opened on today.
  @visibleForTesting
  static DateTime clampInitialDate(DateTime date, DateTime first, DateTime last) {
    if (date.isAfter(last)) return last;
    if (date.isBefore(first)) return first;
    return date;
  }

  Future<void> _pick(BuildContext context) async {
    final first = firstDate ?? DateTime(2000);
    final last = lastDate ?? DateTime(2100);
    final picked = await showDatePicker(
      context: context,
      initialDate: clampInitialDate(value ?? DateTime.now(), first, last),
      firstDate: first,
      lastDate: last,
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
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
            ),
            child: Text(
              formatted ?? hint ?? 'Sélectionner une date',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
