import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AppNumberStepper extends StatelessWidget {
  final int value;
  final int min;
  final int? max;
  final ValueChanged<int> onChanged;

  const AppNumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            alignment: Alignment.center,
            child: Text('$value', style: AppTypography.bodyStrong),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: (max == null || value < max!)
                ? () => onChanged(value + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
