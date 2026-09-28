import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/prosthetic_case_data.dart';
import '../../data/models/prosthetic_case_status_history_data.dart';

class ProstheticHistoryTile extends StatelessWidget {
  final ProstheticCaseStatusHistoryData history;
  final DateFormat dateFmt;
  const ProstheticHistoryTile({
    super.key,
    required this.history,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final to = ProstheticCaseStatus.fromWire(history.toStatus);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.brandPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(to.label, style: AppTypography.bodyStrong),
                Text(
                  '${dateFmt.format(history.createdAt)} · ${history.changedByName}',
                  style: AppTypography.caption,
                ),
                if (history.note != null && history.note!.isNotEmpty)
                  Text(history.note!, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
