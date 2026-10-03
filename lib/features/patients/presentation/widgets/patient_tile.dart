import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
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
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          EntityMark.initials(patient.initials),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DOSSIER PATIENT', style: AppTypography.eyebrow),
                const SizedBox(height: 2),
                Text(
                  patient.reference.isNotEmpty
                      ? patient.reference
                      : 'Dossier sans référence',
                  style: AppTypography.cardTitle,
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            const Icon(Icons.chevron_right,
                color: AppColors.textTertiary, size: 20),
        ],
      ),
    );
  }
}
