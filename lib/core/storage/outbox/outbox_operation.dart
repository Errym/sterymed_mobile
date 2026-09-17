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
        return 'Sortie de stock';
      case OutboxOperation.stockAdjust:
        return 'Ajustement de stock';
      case OutboxOperation.stockTransfer:
        return 'Transfert de stock';
      case OutboxOperation.goodsReceipt:
        return 'Réception marchandise';
      case OutboxOperation.cycleTransition:
        return 'Transition cycle';
      case OutboxOperation.prostheticTransition:
        return 'Transition dossier prothétique';
      case OutboxOperation.prostheticAttachment:
        return 'Pièce jointe prothèse';
      case OutboxOperation.payment:
        return 'Paiement';
    }
  }
}
