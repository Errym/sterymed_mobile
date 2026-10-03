import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/cycle_data.dart';

class CycleInfoCard extends StatelessWidget {
  final CycleData cycle;
  const CycleInfoCard({super.key, required this.cycle});

  @override
  Widget build(BuildContext context) {
    final c = cycle;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          _row(Icons.precision_manufacturing_outlined, 'Appareil',
              c.deviceName.isEmpty ? 'Appareil inconnu' : c.deviceName),
          if (c.programName != null)
            _row(Icons.thermostat_outlined, 'Programme', c.programName!),
          if (c.programTemperatureCelsius != null &&
              c.programPlateauMinutes != null)
            _row(Icons.speed_outlined, 'Paramètres',
                '${c.programTemperatureCelsius} °C · ${c.programPlateauMinutes} min'),
          if (c.operatorName != null)
            _row(Icons.person_outline, 'Opérateur', c.operatorName!),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTypography.label),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodyStrong,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
