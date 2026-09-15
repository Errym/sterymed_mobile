import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/media/app_avatar.dart';
import '../../data/models/patient_data.dart';

class PatientTile extends StatelessWidget {
  final PatientData patient;
  final VoidCallback? onTap;

  const PatientTile({super.key, required this.patient, this.onTap});

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
          child: Row(
            children: [
              AppAvatar(initials: patient.initials, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.fullName, style: AppTypography.bodyStrong),
                    if (patient.reference != null) ...[
                      const SizedBox(height: 2),
                      Text(patient.reference!, style: AppTypography.caption),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
