import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/formatters/currency_formatter.dart';
import '../../../../shared/widgets/inputs/app_text_area.dart';
import '../../data/models/prosthetic_case_data.dart';

/// What the user chose in [ProstheticStatusChangeDialog].
class ProstheticStatusChange {
  final String? note;
  final DateTime? plannedPlacementDate;
  const ProstheticStatusChange({this.note, this.plannedPlacementDate});
}

/// Every status change goes through here (brief §4: "each status change
/// stores date, time, user, optional note"), so the note is always offered.
///
/// * Cancelled and Placed are critical: the title says so and the button is
///   styled as a confirmation, never a one-tap action.
/// * Scheduling asks for the planned placement date.
/// * Placing a case that still has an outstanding payment shows a WARNING
///   (brief §8) but never blocks: the clinic can place first and settle after.
class ProstheticStatusChangeDialog extends StatefulWidget {
  final ProstheticCaseData current;
  final ProstheticCaseStatus target;

  const ProstheticStatusChangeDialog({
    super.key,
    required this.current,
    required this.target,
  });

  static Future<ProstheticStatusChange?> show(
    BuildContext context, {
    required ProstheticCaseData current,
    required ProstheticCaseStatus target,
  }) {
    return showDialog<ProstheticStatusChange>(
      context: context,
      builder: (_) =>
          ProstheticStatusChangeDialog(current: current, target: target),
    );
  }

  /// Critical transitions need an explicit confirmation.
  static bool isCritical(ProstheticCaseStatus s) =>
      s == ProstheticCaseStatus.placed || s == ProstheticCaseStatus.cancelled;

  @override
  State<ProstheticStatusChangeDialog> createState() =>
      _ProstheticStatusChangeDialogState();
}

class _ProstheticStatusChangeDialogState
    extends State<ProstheticStatusChangeDialog> {
  final _noteCtrl = TextEditingController();
  late DateTime? _planned =
      widget.target == ProstheticCaseStatus.placementScheduled
          ? (widget.current.plannedPlacementDate ??
              DateTime.now().add(const Duration(days: 1)))
          : null;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _title => switch (widget.target) {
        ProstheticCaseStatus.placed => 'Confirmer la pose ?',
        ProstheticCaseStatus.cancelled => 'Annuler ce dossier ?',
        _ => 'Passer à « ${widget.target.label} » ?',
      };

  bool get _warnOutstandingPayment =>
      widget.target == ProstheticCaseStatus.placed &&
      widget.current.hasPaymentDue;

  String get _paymentWarning {
    final c = widget.current;
    final parts = <String>[];
    if (c.depositRequested && !c.depositReceived) {
      parts.add('acompte demandé, non reçu');
    }
    if (c.remainingBalance != null && c.remainingBalance! > 0) {
      parts.add(
        'solde restant ${AppCurrencyFormatter.eur(c.remainingBalance!)}',
      );
    }
    return 'Paiement à vérifier : ${parts.join(', ')}. '
        'Vous pouvez poser quand même.';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _planned ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Date de pose prévue',
    );
    if (picked != null && mounted) setState(() => _planned = picked);
  }

  @override
  Widget build(BuildContext context) {
    final critical = ProstheticStatusChangeDialog.isCritical(widget.target);
    return AlertDialog(
      title: Text(_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_warnOutstandingPayment) ...[
              Container(
                key: const Key('status-payment-warning'),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_outlined,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(_paymentWarning, style: AppTypography.caption),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (widget.target == ProstheticCaseStatus.placementScheduled) ...[
              OutlinedButton.icon(
                key: const Key('status-planned-date'),
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _planned == null
                      ? 'Choisir la date de pose'
                      : 'Pose prévue le ${_dateFmt.format(_planned!)}',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppTextArea(
              label: 'Note (optionnel)',
              controller: _noteCtrl,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Retour'),
        ),
        FilledButton(
          key: const Key('status-confirm'),
          style: widget.target == ProstheticCaseStatus.cancelled
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.of(context).pop(
            ProstheticStatusChange(
              note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
              plannedPlacementDate: _planned,
            ),
          ),
          child: Text(critical ? 'Confirmer' : 'Valider'),
        ),
      ],
    );
  }
}
