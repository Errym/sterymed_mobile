import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/models/dashboard_data.dart';

class KpiRow extends StatelessWidget {
  final List<DashboardKpi> kpis;
  final void Function(String route) onTap;

  const KpiRow({super.key, required this.kpis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (kpis.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.4,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        return _KpiTile(kpi: kpi, onTap: () => onTap(kpi.route));
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  final DashboardKpi kpi;
  final VoidCallback onTap;

  const _KpiTile({required this.kpi, required this.onTap});

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
            color: AppColors.brandPrimaryExtraLight,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${kpi.value}',
                style: AppTypography.kpiNumber.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
              const Spacer(),
              Text(
                kpi.label,
                style: AppTypography.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
