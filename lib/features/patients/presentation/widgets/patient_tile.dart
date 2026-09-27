import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/media/app_avatar.dart';
import '../../data/models/patient_data.dart';

class PatientTile extends StatelessWidget {
  final PatientData patient;
  final VoidCallback? onTap;
  final Widget? trailing;

  const PatientTile({
    super.key,
    required this.patient,
    this.onTap,
    this.trailing,
  });

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
                child: Text(
                  patient.reference.isNotEmpty
                      ? patient.reference
                      : 'Dossier sans référence',
                  style: AppTypography.bodyStrong,
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(Icons.chevron_right,
                    color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
