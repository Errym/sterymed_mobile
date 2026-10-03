import 'package:equatable/equatable.dart';

class AuditEventData extends Equatable {
  final String id;
  final String? actorId;
  final String? actorLabel;
  final String action;
  final String? subjectType;
  final String? subjectId;
  final String? reason;
  final DateTime occurredAt;

  /// The record before and after the action, as the server stored them. Either
  /// can be absent (a creation has no "before", a deletion no "after").
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;

  const AuditEventData({
    required this.id,
    this.actorId,
    this.actorLabel,
    required this.action,
    this.subjectType,
    this.subjectId,
    this.reason,
    required this.occurredAt,
    this.oldValues,
    this.newValues,
  });

  factory AuditEventData.fromJson(Map<String, dynamic> json) => AuditEventData(
        id: json['id']?.toString() ?? '',
        actorId: json['actor_id']?.toString(),
        actorLabel: json['actor_label_snapshot']?.toString(),
        action: json['action']?.toString() ?? '',
        subjectType: json['subject_type']?.toString(),
        subjectId: json['subject_id']?.toString(),
        reason: json['reason']?.toString(),
        occurredAt:
            DateTime.tryParse(json['occurred_at']?.toString() ?? '') ??
                DateTime.now(),
        oldValues: _asMap(json['old_values']),
        newValues: _asMap(json['new_values']),
      );

  static Map<String, dynamic>? _asMap(Object? v) {
    if (v is! Map || v.isEmpty) return null;
    return v.map((k, val) => MapEntry(k.toString(), val));
  }

  /// A field whose value must never be displayed, whatever the server sent.
  static bool isSensitiveField(String field) {
    final f = field.toLowerCase();
    return f.contains('password') ||
        f.contains('token') ||
        f.contains('secret') ||
        f.contains('remember');
  }

  /// "shelf_life_days" -> "Shelf life days".
  static String prettyField(String field) {
    final spaced = field.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return field;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  static String _show(Object? v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'oui' : 'non';
    if (v is Map || v is List) return v.toString();
    final s = v.toString();
    return s.isEmpty ? '—' : s;
  }

  /// What changed, field by field: only fields whose value differs. Sensitive
  /// fields appear as changed but never with their values.
  List<({String field, String before, String after})> get changes {
    final before = oldValues ?? const <String, dynamic>{};
    final after = newValues ?? const <String, dynamic>{};
    final fields = {...before.keys, ...after.keys}.toList()..sort();
    final out = <({String field, String before, String after})>[];
    for (final f in fields) {
      final b = before[f];
      final a = after[f];
      if (b == a || (b?.toString() == a?.toString())) continue;
      final hidden = isSensitiveField(f);
      out.add((
        field: prettyField(f),
        before: hidden ? '••••' : _show(b),
        after: hidden ? '••••' : _show(a),
      ));
    }
    return out;
  }

  /// Every action the server records, in the words of the clinic. The keys
  /// are the server's stable codes; an action not listed yet falls back to
  /// its code so it is never hidden.
  static const actionLabels = <String, String>{
    'auth.login_succeeded': 'Connexion réussie',
    'auth.login_denied': 'Échec de connexion',
    'auth.logout': 'Déconnexion',
    'auth.logout_everywhere': 'Déconnexion de tous les appareils',
    'tenant.registered': 'Cabinet enregistré',
    'tenant.identity_updated': 'Identité du cabinet modifiée',
    'tenant.logo_updated': 'Logo du cabinet modifié',
    'invitation.created': 'Invitation envoyée',
    'invitation.resent': 'Invitation renvoyée',
    'invitation.revoked': 'Invitation annulée',
    'invitation.accepted': 'Invitation acceptée',
    'product.created': 'Produit créé',
    'product.updated': 'Produit modifié',
    'product.deleted': 'Produit supprimé',
    'supplier.created': 'Fournisseur créé',
    'supplier.updated': 'Fournisseur modifié',
    'supplier.deleted': 'Fournisseur supprimé',
    'purchase_order.created': 'Commande créée',
    'purchase_order.updated': 'Commande modifiée',
    'purchase_order.ordered': 'Commande passée',
    'purchase_order.cancelled': 'Commande annulée',
    'goods_receipt.created': 'Réception enregistrée',
    'goods_receipt_attachment.added': 'Justificatif de réception ajouté',
    'stock.issued': 'Sortie de stock',
    'stock.adjusted': 'Ajustement de stock',
    'stock.transferred': 'Transfert de stock',
    'batch.quarantined': 'Lot mis en quarantaine',
    'inventory_count.opened': 'Inventaire ouvert',
    'inventory_count.line_recorded': 'Ligne d\'inventaire saisie',
    'inventory_count.closed': 'Inventaire clôturé',
    'inventory_count.cancelled': 'Inventaire annulé',
    'storage_location.created': 'Emplacement créé',
    'storage_location.updated': 'Emplacement modifié',
    'storage_location.archived': 'Emplacement archivé',
    'cycle.created': 'Cycle créé',
    'cycle.started': 'Cycle démarré',
    'cycle.completed': 'Cycle terminé',
    'cycle.submitted_for_release': 'Cycle soumis à la libération',
    'cycle.released': 'Cycle libéré',
    'cycle.rejected': 'Cycle rejeté',
    'cycle_item.created': 'Instrument ajouté au cycle',
    'cycle_item.updated': 'Instrument du cycle modifié',
    'cycle_item.deleted': 'Instrument retiré du cycle',
    'cycle_attachment.added': 'Pièce jointe de cycle ajoutée',
    'cycle_attachment.removed': 'Pièce jointe de cycle retirée',
    'control_test.recorded': 'Contrôle enregistré',
    'labels.generated': 'Étiquettes générées',
    'label.printed': 'Étiquette imprimée',
    'label.used': 'Étiquette utilisée',
    'label.recalled': 'Étiquette rappelée',
    'label.use_blocked_expired': 'Utilisation bloquée (étiquette périmée)',
    'label_usage.recorded': 'Utilisation enregistrée',
    'label_format.updated': 'Format d\'étiquette modifié',
    'dlu_rule.created': 'Règle DLU créée',
    'dlu_rule.updated': 'Règle DLU modifiée',
    'dlu_rule.deleted': 'Règle DLU supprimée',
    'device.created': 'Appareil créé',
    'device.updated': 'Appareil modifié',
    'device.deleted': 'Appareil supprimé',
    'device_program.created': 'Programme créé',
    'device_program.updated': 'Programme modifié',
    'device_program.deleted': 'Programme supprimé',
    'maintenance_record.created': 'Maintenance enregistrée',
    'site.created': 'Site créé',
    'site.updated': 'Site modifié',
    'site.archived': 'Site archivé',
    'room.created': 'Salle créée',
    'room.updated': 'Salle modifiée',
    'room.archived': 'Salle archivée',
    'alert.resolved': 'Alerte résolue',
    'alert_settings.updated': 'Réglages d\'alertes modifiés',
    'digest_subscriptions.updated': 'Abonnement au récapitulatif modifié',
    'non_conformity.raised': 'Non-conformité déclarée',
    'non_conformity.resolved': 'Non-conformité résolue',
    'patient.created': 'Dossier patient créé',
    'patient.archived': 'Dossier patient archivé',
    'prosthetic_case.created': 'Travail prothétique créé',
    'prosthetic_case.updated': 'Travail prothétique modifié',
    'prosthetic_case.status_changed': 'Statut du travail prothétique modifié',
    'prosthetic_case_attachment.added': 'Pièce jointe prothétique ajoutée',
    'prosthetic_case_attachment.removed': 'Pièce jointe prothétique retirée',
    'data_export.requested': 'Export de données demandé',
    'data_export.downloaded': 'Export de données téléchargé',
  };

  String get actionLabel => actionLabels[action] ?? action;

  String? get subjectTypeLabel {
    const map = {
      'App\\Domain\\Sterilization\\Models\\Cycle': 'Cycle',
      'App\\Domain\\Sterilization\\Models\\CycleItem':
          'Instrument de cycle',
      'App\\Domain\\Catalog\\Models\\Product': 'Produit',
      'App\\Domain\\Purchasing\\Models\\Supplier': 'Fournisseur',
      'App\\Domain\\Purchasing\\Models\\PurchaseOrder': 'Commande',
      'App\\Domain\\Equipment\\Models\\Device': 'Appareil',
      'App\\Domain\\Equipment\\Models\\MaintenanceRecord':
          'Fiche de maintenance',
      'App\\Domain\\Reporting\\Models\\DataExportRequest':
          'Export de données',
      'App\\Models\\User': 'Utilisateur',
    };
    if (subjectType == null) return null;
    final mapped = map[subjectType];
    if (mapped != null) return mapped;
    final last = subjectType!.split('\\').last;
    return last.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (_) => ' ',
    );
  }

  @override
  List<Object?> get props => [
        id,
        actorId,
        actorLabel,
        action,
        subjectType,
        subjectId,
        occurredAt,
        oldValues,
        newValues,
      ];
}
