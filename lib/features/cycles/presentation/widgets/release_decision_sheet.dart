import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';

class ReleaseDecisionResult {
  final String decision;
  final String? reason;
  ReleaseDecisionResult({required this.decision, this.reason});
}

class ReleaseDecisionSheet extends StatefulWidget {
  const ReleaseDecisionSheet({super.key});

  static Future<ReleaseDecisionResult?> show(BuildContext context) {
    return showModalBottomSheet<ReleaseDecisionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => const ReleaseDecisionSheet(),
    );
  }

  @override
  State<ReleaseDecisionSheet> createState() => _ReleaseDecisionSheetState();
}

class _ReleaseDecisionSheetState extends State<ReleaseDecisionSheet> {
  String _decision = 'compliant';
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requiresReason = _decision == 'rejected';
    final canSubmit = !requiresReason || _reasonCtrl.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 160),
              decoration: BoxDecoration(
                color: AppColors.borderMedium,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Décision de libération', style: AppTypography.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            _option(
              title: 'Conforme — libérer le cycle',
              value: 'compliant',
              color: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.sm),
            _option(
              title: 'Rejeté — cycle non libéré',
              value: 'rejected',
              color: AppColors.danger,
            ),
            const SizedBox(height: AppSpacing.md),
            if (requiresReason)
              AppTextArea(
                label: 'Motif du rejet (obligatoire)',
                controller: _reasonCtrl,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
              ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Valider la décision',
              onPressed: canSubmit
                  ? () => Navigator.of(context).pop(
                        ReleaseDecisionResult(
                          decision: _decision,
                          reason:
                              requiresReason ? _reasonCtrl.text.trim() : null,
                        ),
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _option({
    required String title,
    required String value,
    required Color color,
  }) {
    final selected = _decision == value;
    return InkWell(
      onTap: () => setState(() => _decision = value),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.08)
              : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? color : AppColors.borderLight,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: AppTypography.bodyStrong.copyWith(
                  color: selected ? color : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
