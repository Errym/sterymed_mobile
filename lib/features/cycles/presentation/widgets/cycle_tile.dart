import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/cycle_data.dart';
import 'cycle_status_badge.dart';

class CycleTile extends StatelessWidget {
  final CycleData cycle;
  final VoidCallback? onTap;

  const CycleTile({super.key, required this.cycle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cycle ${cycle.number}',
                      style: AppTypography.bodyStrong,
                    ),
                  ),
                  CycleStatusBadge(status: cycle.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.precision_manufacturing_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      cycle.deviceName,
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.schedule,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(cycle.createdAt),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}