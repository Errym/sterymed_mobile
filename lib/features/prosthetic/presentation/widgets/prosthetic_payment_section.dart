import 'package:flutter/material.dart';

import '../../../../core/utils/decimal_input.dart';

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

  /// The remaining balance as the server will compute it: with a total on the
  /// case it is `total - deposit actually received`, never below zero, and
  /// nothing once the final payment is done. Without a total the balance is
  /// typed by hand (still forced to zero once the final payment is done).
  /// Null when the figures typed so far are not readable amounts.
  static double? previewBalance({
    required String total,
    required String deposit,
    required bool depositReceived,
    required bool finalPaymentCompleted,
  }) {
    if (finalPaymentCompleted) return 0;
    final parsedTotal = DecimalInput.parse(total);
    if (parsedTotal == null) return null;
    final received = depositReceived ? (DecimalInput.parse(deposit) ?? 0) : 0;
    final left = parsedTotal - received;
    return left < 0 ? 0 : left;
  }

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
  late final _totalAmountCtrl = TextEditingController(
    text: widget.data.totalAmount?.toStringAsFixed(2) ?? '',
  );
  late final _remainingBalanceCtrl = TextEditingController(
    text: widget.data.remainingBalance?.toStringAsFixed(2) ?? '',
  );
  late final _administrativeCommentsCtrl = TextEditingController(
    text: widget.data.administrativeComments ?? '',
  );

  @override
  void initState() {
    super.initState();
    // Brief §8: the balance follows the figures as they are typed.
    _depositAmountCtrl.addListener(_recalculate);
    _totalAmountCtrl.addListener(_recalculate);
  }

  @override
  void dispose() {
    _depositAmountCtrl.dispose();
    _totalAmountCtrl.dispose();
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
    _finalPaymentCompleted = v;
    _recalculate();
  }

  bool get _hasTotal => DecimalInput.parse(_totalAmountCtrl.text) != null;

  void _recalculate() {
    final preview = ProstheticPaymentSection.previewBalance(
      total: _totalAmountCtrl.text,
      deposit: _depositAmountCtrl.text,
      depositReceived: _depositReceived,
      finalPaymentCompleted: _finalPaymentCompleted,
    );
    setState(() {
      if (preview != null) _remainingBalanceCtrl.text = preview.toStringAsFixed(2);
    });
  }

  bool _depositInvalid = false;
  bool _totalInvalid = false;
  bool _balanceInvalid = false;

  void _save() {
    // An unreadable amount must never be sent: null in a PATCH clears the field.
    final badDeposit = DecimalInput.isInvalid(_depositAmountCtrl.text);
    final badTotal = DecimalInput.isInvalid(_totalAmountCtrl.text);
    final badBalance = !_finalPaymentCompleted &&
        !_hasTotal &&
        DecimalInput.isInvalid(_remainingBalanceCtrl.text);
    setState(() {
      _depositInvalid = badDeposit;
      _totalInvalid = badTotal;
      _balanceInvalid = badBalance;
    });
    if (badDeposit || badTotal || badBalance) return;
    widget.onSave({
      'deposit_requested': _depositRequested,
      'deposit_received': _depositReceived,
      'deposit_amount': DecimalInput.parse(_depositAmountCtrl.text),
      'total_amount': DecimalInput.parse(_totalAmountCtrl.text),
      'final_payment_completed': _finalPaymentCompleted,
      // With a total the server derives the balance itself; the typed one is
      // only sent when there is no total to derive it from.
      if (!_hasTotal)
        'remaining_balance': _finalPaymentCompleted
            ? 0.0
            : DecimalInput.parse(_remainingBalanceCtrl.text),
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
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
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
              onChanged: (v) {
                _depositReceived = v;
                _recalculate();
              },
            ),
            AppTextField(
              label: 'Montant total (€)',
              controller: _totalAmountCtrl,
              errorText: _totalInvalid ? DecimalInput.invalidMessage : null,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Montant de l\'acompte (€)',
              controller: _depositAmountCtrl,
              errorText: _depositInvalid ? DecimalInput.invalidMessage : null,
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
              label: _hasTotal
                  ? 'Solde restant (€) — calculé'
                  : 'Solde restant (€)',
              controller: _remainingBalanceCtrl,
              errorText: _balanceInvalid ? DecimalInput.invalidMessage : null,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              // Computed from the total once there is one, and zero once the
              // final payment is done: only typed by hand otherwise.
              enabled: !_finalPaymentCompleted && !_hasTotal,
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
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.card,
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
