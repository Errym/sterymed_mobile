import 'package:flutter/widgets.dart';

import '../../data/models/purchase_order_line_data.dart';

/// What the user is typing for one order line while receiving a delivery, and
/// the rules that decide whether it can be sent.
///
/// The server enforces the same rules (it is the authority); checking them
/// here means the user fixes a typo on the spot instead of after a round trip
/// that, offline, would only fail much later.
class ReceiptLineDraft {
  ReceiptLineDraft(this.line)
    : qtyCtrl = TextEditingController(text: '${line.qtyRemaining}'),
      lotCtrl = TextEditingController(),
      reasonCtrl = TextEditingController();

  final PurchaseOrderLineData line;
  final TextEditingController qtyCtrl;
  final TextEditingController lotCtrl;
  final TextEditingController reasonCtrl;
  DateTime? expiry;

  /// The product genuinely has no expiry date (the user says so explicitly,
  /// instead of leaving the field empty by accident).
  bool noExpiry = false;

  /// Nothing left to receive on this line.
  bool get isComplete => line.qtyRemaining == 0;

  int? get qty => int.tryParse(qtyCtrl.text.trim());

  /// Goes into the receipt: something is coming in now.
  bool get included => !isComplete && (qty ?? 0) > 0;

  /// The delivered quantity differs from what is still expected.
  bool get differsFromOrder => included && qty != line.qtyRemaining;

  String? get qtyError {
    if (isComplete) return null;
    final text = qtyCtrl.text.trim();
    if (text.isEmpty) return 'Saisissez une quantité (0 si rien n\'arrive).';
    final q = int.tryParse(text);
    if (q == null || q < 0) return 'Entrez un nombre entier positif.';
    if (q > line.qtyRemaining) {
      return 'Maximum ${line.qtyRemaining} : c\'est ce qui reste à recevoir.';
    }
    return null;
  }

  String? get lotError {
    if (!included) return null;
    final lot = lotCtrl.text.trim();
    if (lot.isEmpty) {
      return 'Numéro de lot requis (inscrit sur l\'emballage).';
    }
    if (lot.length > 255) return 'Numéro de lot trop long.';
    return null;
  }

  String? expiryError({DateTime? today}) {
    if (!included || noExpiry) return null;
    final e = expiry;
    if (e == null) {
      return 'Date de péremption requise (ou cochez « sans date »).';
    }
    final now = today ?? DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    if (DateTime(e.year, e.month, e.day).isBefore(startOfToday)) {
      return 'Date dépassée : un produit périmé ne peut pas être réceptionné.';
    }
    return null;
  }

  bool isValid({DateTime? today}) =>
      qtyError == null && lotError == null && expiryError(today: today) == null;

  /// The line as the API expects it. Only call for an [included] line.
  Map<String, dynamic> toPayload() {
    final e = expiry;
    final reason = reasonCtrl.text.trim();
    return {
      'purchase_order_line_id': line.id,
      'batch_number': lotCtrl.text.trim(),
      'qty': qty,
      if (!noExpiry && e != null)
        'expiry_date':
            '${e.year.toString().padLeft(4, '0')}-'
            '${e.month.toString().padLeft(2, '0')}-'
            '${e.day.toString().padLeft(2, '0')}',
      if (reason.isNotEmpty) 'discrepancy_reason': reason,
    };
  }

  void dispose() {
    qtyCtrl.dispose();
    lotCtrl.dispose();
    reasonCtrl.dispose();
  }
}
