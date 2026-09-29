import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/formatters/currency_formatter.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/models/prosthetic_case_data.dart';

/// Read-only display for anyone without `prosthetic_payments.manage` —
/// hide-not-disable would mean showing nothing at all here, but "can this
/// patient be placed without an outstanding balance?" is exactly the
/// question a clinician (who can't edit these fields) still needs
/// answered at a glance (brief page 8's own reasoning for why clinicians
/// stay able to see, not edit, this section).
class ProstheticPaymentSection extends StatefulWidget {
  final ProstheticCaseData data;
  final bool canEdit;
  final bool busy;
  final ValueChanged<Map<String, dynamic>> onSave;

  const ProstheticPaymentSection({
    super.key,
    required this.data,
    required this.canEdit,
    required this.busy,
    required this.onSave,
  });

  @override
  State<ProstheticPaymentSection> createState() =>
      _ProstheticPaymentSectionState();
}

class _ProstheticPaymentSectionState extends State<ProstheticPaymentSection> {
  late bool _depositRequested = widget.data.depositRequested;
  late bool _depositReceived = widget.data.depositReceived;
  late bool _finalPaymentCompleted = widget.data.finalPaymentCompleted;
  late final _depositAmountCtrl = TextEditingController(
    text: widget.data.depositAmount?.toStringAsFixed(2) ?? '',
  );
  late final _remainingBalanceCtrl = TextEditingController(
    text: widget.data.remainingBalance?.toStringAsFixed(2) ?? '',
  );
  late final _administrativeCommentsCtrl = TextEditingController(
    text: widget.data.administrativeComments ?? '',
  );

  @override
  void dispose() {
    _depositAmountCtrl.dispose();
    _remainingBalanceCtrl.dispose();
    _administrativeCommentsCtrl.dispose();
    super.dispose();
  }

  // Brief page 8: "remaining balance should be automatically recalculated
  // when amounts change." Neither this model nor the backend has a total
  // case price to derive a balance from — deposit and remaining balance
  // are independent figures — but one invariant IS always true regardless
  // of that: a case with the final payment completed cannot still have a
  // balance owed. Enforced both live (as the switch is toggled) and again
  // here at save time, so it holds even if a future change lets the field
  // become editable again while the switch is on.
  void _onFinalPaymentToggled(bool v) {
    setState(() {
      _finalPaymentCompleted = v;
      if (v) _remainingBalanceCtrl.text = '0.00';
    });
  }

  void _save() {
    widget.onSave({
      'deposit_requested': _depositRequested,
      'deposit_received': _depositReceived,
      'deposit_amount': double.tryParse(_depositAmountCtrl.text.trim()),
      'final_payment_completed': _finalPaymentCompleted,
      'remaining_balance': _finalPaymentCompleted
          ? 0.0
          : double.tryParse(_remainingBalanceCtrl.text.trim()),
      'administrative_comments': _administrativeCommentsCtrl.text.trim().isEmpty
          ? null
          : _administrativeCommentsCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canEdit) {
      return _ReadOnlyPaymentCard(data: widget.data);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      // SwitchListTile paints its ink/background on the nearest Material
      // ancestor — without this, the decorated Container above hides that
      // painting entirely (Flutter's own framework assertion: "ListTile
      // background color or ink splashes may be invisible").
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Acompte demandé'),
              value: _depositRequested,
              onChanged: (v) => setState(() => _depositRequested = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Acompte reçu'),
              value: _depositReceived,
              onChanged: (v) => setState(() => _depositReceived = v),
            ),
            AppTextField(
              label: 'Montant de l\'acompte (€)',
              controller: _depositAmountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Paiement final effectué'),
              value: _finalPaymentCompleted,
              onChanged: _onFinalPaymentToggled,
            ),
            AppTextField(
              label: 'Solde restant (€)',
              controller: _remainingBalanceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              enabled: !_finalPaymentCompleted,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextArea(
              label: 'Commentaires administratifs',
              controller: _administrativeCommentsCtrl,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Enregistrer le paiement',
              isLoading: widget.busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyPaymentCard extends StatelessWidget {
  final ProstheticCaseData data;
  const _ReadOnlyPaymentCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: data.hasPaymentDue
            ? AppColors.dangerLight
            : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                data.hasPaymentDue
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outline,
                color:
                    data.hasPaymentDue ? AppColors.danger : AppColors.success,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                data.hasPaymentDue ? 'Paiement à vérifier' : 'Paiement à jour',
                style: AppTypography.bodyStrong,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.depositRequested
                ? (data.depositReceived
                    ? 'Acompte reçu (${data.depositAmount != null ? AppCurrencyFormatter.eur(data.depositAmount!) : '?'}).'
                    : 'Acompte demandé, non reçu.')
                : 'Aucun acompte demandé.',
            style: AppTypography.caption,
          ),
          if (data.remainingBalance != null && data.remainingBalance! > 0)
            Text(
                'Solde restant : ${AppCurrencyFormatter.eur(data.remainingBalance!)}',
                style: AppTypography.caption),
        ],
      ),
    );
  }
}
