enum OutboxOperation {
  labelUsage,
  stockIssue,
  stockAdjust,
  stockTransfer,
  goodsReceipt,
  cycleTransition,
  prostheticTransition,
  prostheticAttachment,
  payment,
}

extension OutboxOperationLabel on OutboxOperation {
  String get label {
    switch (this) {
      case OutboxOperation.labelUsage:
        return 'Utilisation étiquette';
      case OutboxOperation.stockIssue:
        return 'Sortie stock';
      case OutboxOperation.stockAdjust:
        return 'Ajustement stock';
      case OutboxOperation.stockTransfer:
        return 'Transfert stock';
      case OutboxOperation.goodsReceipt:
        return 'Réception marchandise';
      case OutboxOperation.cycleTransition:
        return 'Transition cycle';
      case OutboxOperation.prostheticTransition:
        return 'Transition dossier';
      case OutboxOperation.prostheticAttachment:
        return 'Pièce jointe dossier';
      case OutboxOperation.payment:
        return 'Paiement';
    }
  }
}
