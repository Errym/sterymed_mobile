import 'package:equatable/equatable.dart';

enum ProstheticCaseStatus {
  impressionCompleted,
  sentToLaboratory,
  receivedAtPractice,
  placementScheduled,
  placed,
  cancelled,
  unknown;

  static ProstheticCaseStatus fromWire(String value) => switch (value) {
        'impression_completed' => ProstheticCaseStatus.impressionCompleted,
        'sent_to_laboratory' => ProstheticCaseStatus.sentToLaboratory,
        'received_at_practice' => ProstheticCaseStatus.receivedAtPractice,
        'placement_scheduled' => ProstheticCaseStatus.placementScheduled,
        'placed' => ProstheticCaseStatus.placed,
        'cancelled' => ProstheticCaseStatus.cancelled,
        _ => ProstheticCaseStatus.unknown,
      };

  String get wire => switch (this) {
        ProstheticCaseStatus.impressionCompleted => 'impression_completed',
        ProstheticCaseStatus.sentToLaboratory => 'sent_to_laboratory',
        ProstheticCaseStatus.receivedAtPractice => 'received_at_practice',
        ProstheticCaseStatus.placementScheduled => 'placement_scheduled',
        ProstheticCaseStatus.placed => 'placed',
        ProstheticCaseStatus.cancelled => 'cancelled',
        ProstheticCaseStatus.unknown => '',
      };

  String get label => switch (this) {
        ProstheticCaseStatus.impressionCompleted => 'Empreinte réalisée',
        ProstheticCaseStatus.sentToLaboratory => 'Envoyé au laboratoire',
        ProstheticCaseStatus.receivedAtPractice => 'Reçu au cabinet',
        ProstheticCaseStatus.placementScheduled => 'Pose programmée',
        ProstheticCaseStatus.placed => 'Posé',
        ProstheticCaseStatus.cancelled => 'Annulé',
        ProstheticCaseStatus.unknown => 'Statut inconnu',
      };

  /// Mirrors the backend's `ProstheticCaseStatus::allowedNextStatuses()`
  /// exactly — the UI never offers a transition the server would reject.
  List<ProstheticCaseStatus> get allowedNext => switch (this) {
        ProstheticCaseStatus.impressionCompleted => [
            ProstheticCaseStatus.sentToLaboratory,
            ProstheticCaseStatus.cancelled,
          ],
        ProstheticCaseStatus.sentToLaboratory => [
            ProstheticCaseStatus.receivedAtPractice,
            ProstheticCaseStatus.cancelled,
          ],
        ProstheticCaseStatus.receivedAtPractice => [
            ProstheticCaseStatus.placementScheduled,
            ProstheticCaseStatus.cancelled,
          ],
        ProstheticCaseStatus.placementScheduled => [
            ProstheticCaseStatus.placed,
            ProstheticCaseStatus.cancelled,
          ],
        ProstheticCaseStatus.placed => [],
        ProstheticCaseStatus.cancelled => [
            ProstheticCaseStatus.impressionCompleted,
          ],
        ProstheticCaseStatus.unknown => [],
      };
}

enum ProstheticImpressionType {
  digital,
  physical;

  static ProstheticImpressionType fromWire(String value) =>
      value == 'physical'
          ? ProstheticImpressionType.physical
          : ProstheticImpressionType.digital;

  String get wire =>
      this == ProstheticImpressionType.physical ? 'physical' : 'digital';

  String get label =>
      this == ProstheticImpressionType.physical ? 'Physique' : 'Numérique';
}

enum ProstheticWorkType {
  crown,
  bridge,
  implant,
  aligner,
  veneer,
  denture,
  other;

  static ProstheticWorkType fromWire(String value) => switch (value) {
        'crown' => ProstheticWorkType.crown,
        'bridge' => ProstheticWorkType.bridge,
        'implant' => ProstheticWorkType.implant,
        'aligner' => ProstheticWorkType.aligner,
        'veneer' => ProstheticWorkType.veneer,
        'denture' => ProstheticWorkType.denture,
        _ => ProstheticWorkType.other,
      };

  String get wire => switch (this) {
        ProstheticWorkType.crown => 'crown',
        ProstheticWorkType.bridge => 'bridge',
        ProstheticWorkType.implant => 'implant',
        ProstheticWorkType.aligner => 'aligner',
        ProstheticWorkType.veneer => 'veneer',
        ProstheticWorkType.denture => 'denture',
        ProstheticWorkType.other => 'other',
      };

  String get label => switch (this) {
        ProstheticWorkType.crown => 'Couronne',
        ProstheticWorkType.bridge => 'Bridge',
        ProstheticWorkType.implant => 'Implant',
        ProstheticWorkType.aligner => 'Gouttière',
        ProstheticWorkType.veneer => 'Facette',
        ProstheticWorkType.denture => 'Prothèse amovible',
        ProstheticWorkType.other => 'Autre',
      };
}

class ProstheticCaseData extends Equatable {
  final String id;
  final String patientId;
  final String patientReference;
  final String practitionerId;
  final String practitionerName;
  final String? laboratoryId;
  final String? laboratoryName;
  final ProstheticCaseStatus status;
  final String? priority;
  final ProstheticImpressionType impressionType;
  final ProstheticWorkType workType;
  final DateTime impressionDate;
  final DateTime? sentToLabDate;
  final DateTime? returnedFromLabDate;
  final DateTime? plannedPlacementDate;
  final DateTime? actualPlacementDate;
  final int? daysWaitingForPlacement;
  final String? notes;
  final String? internalComments;
  final bool depositRequested;
  final bool depositReceived;
  final double? depositAmount;
  final bool finalPaymentCompleted;
  final double? remainingBalance;
  final String? administrativeComments;
  final DateTime createdAt;

  const ProstheticCaseData({
    required this.id,
    required this.patientId,
    required this.patientReference,
    required this.practitionerId,
    required this.practitionerName,
    this.laboratoryId,
    this.laboratoryName,
    required this.status,
    this.priority,
    required this.impressionType,
    required this.workType,
    required this.impressionDate,
    this.sentToLabDate,
    this.returnedFromLabDate,
    this.plannedPlacementDate,
    this.actualPlacementDate,
    this.daysWaitingForPlacement,
    this.notes,
    this.internalComments,
    this.depositRequested = false,
    this.depositReceived = false,
    this.depositAmount,
    this.finalPaymentCompleted = false,
    this.remainingBalance,
    this.administrativeComments,
    required this.createdAt,
  });

  bool get isWaitingForPlacement =>
      returnedFromLabDate != null &&
      actualPlacementDate == null &&
      status != ProstheticCaseStatus.cancelled;

  bool get hasPaymentDue =>
      (depositRequested && !depositReceived) ||
      (remainingBalance != null && remainingBalance! > 0);

  factory ProstheticCaseData.fromJson(Map<String, dynamic> json) =>
      ProstheticCaseData(
        id: json['id']?.toString() ?? '',
        patientId: json['patient_id']?.toString() ?? '',
        patientReference: json['patient_reference']?.toString() ?? '',
        practitionerId: json['practitioner_id']?.toString() ?? '',
        practitionerName: json['practitioner_name']?.toString() ?? '',
        laboratoryId: json['laboratory_id']?.toString(),
        laboratoryName: json['laboratory_name']?.toString(),
        status: ProstheticCaseStatus.fromWire(
            json['status']?.toString() ?? ''),
        priority: json['priority']?.toString(),
        impressionType: ProstheticImpressionType.fromWire(
            json['impression_type']?.toString() ?? ''),
        workType:
            ProstheticWorkType.fromWire(json['work_type']?.toString() ?? ''),
        impressionDate:
            DateTime.tryParse(json['impression_date']?.toString() ?? '') ??
                DateTime.now(),
        sentToLabDate: DateTime.tryParse(
            json['sent_to_lab_date']?.toString() ?? ''),
        returnedFromLabDate: DateTime.tryParse(
            json['returned_from_lab_date']?.toString() ?? ''),
        plannedPlacementDate: DateTime.tryParse(
            json['planned_placement_date']?.toString() ?? ''),
        actualPlacementDate: DateTime.tryParse(
            json['actual_placement_date']?.toString() ?? ''),
        daysWaitingForPlacement:
            (json['days_waiting_for_placement'] as num?)?.toInt(),
        notes: json['notes']?.toString(),
        internalComments: json['internal_comments']?.toString(),
        depositRequested: json['deposit_requested'] as bool? ?? false,
        depositReceived: json['deposit_received'] as bool? ?? false,
        depositAmount: (json['deposit_amount'] as num?)?.toDouble(),
        finalPaymentCompleted:
            json['final_payment_completed'] as bool? ?? false,
        remainingBalance: (json['remaining_balance'] as num?)?.toDouble(),
        administrativeComments: json['administrative_comments']?.toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  @override
  List<Object?> get props => [id, status, updatedFingerprint];

  // Cheap change-detection surface for Equatable without listing every
  // field — status + the two dates most likely to change independently.
  String get updatedFingerprint =>
      '$status|$returnedFromLabDate|$actualPlacementDate|$remainingBalance';
}
