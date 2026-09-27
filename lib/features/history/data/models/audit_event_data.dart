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

  const AuditEventData({
    required this.id,
    this.actorId,
    this.actorLabel,
    required this.action,
    this.subjectType,
    this.subjectId,
    this.reason,
    required this.occurredAt,
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
      );

  String get actionLabel {
    const map = {
      'auth.login_succeeded': 'Connexion réussie',
      'auth.login_denied': 'Échec de connexion',
      'tenant.registered': 'Cabinet enregistré',
      'product.created': 'Produit créé',
      'cycle.created': 'Cycle créé',
      'cycle.started': 'Cycle démarré',
      'cycle.completed': 'Cycle terminé',
      'cycle.released': 'Cycle libéré',
      'cycle.rejected': 'Cycle rejeté',
      'label.printed': 'Étiquette imprimée',
      'label_usage.recorded': 'Utilisation enregistrée',
      'stock_movement.issued': 'Sortie de stock',
      'stock_movement.adjusted': 'Ajustement de stock',
    };
    return map[action] ?? action;
  }

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
    return map[subjectType] ?? subjectType;
  }

  @override
  List<Object?> get props =>
      [id, actorId, actorLabel, action, subjectType, subjectId, occurredAt];
}
