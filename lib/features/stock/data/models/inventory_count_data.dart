import 'package:equatable/equatable.dart';

/// One inventory session as listed (`GET /v1/inventory-counts`) or embedded in
/// the detail answer.
class InventoryCountSummary extends Equatable {
  final String id;
  final String locationId;
  final String locationName;

  /// `open`, `closed` or `cancelled`.
  final String status;
  final String? note;
  final String openedByName;
  final DateTime? openedAt;
  final String? closedByName;
  final DateTime? closedAt;
  final String? cancelReason;
  final int linesCount;
  final int adjustmentsCount;

  const InventoryCountSummary({
    required this.id,
    required this.locationId,
    required this.locationName,
    required this.status,
    required this.openedByName,
    required this.linesCount,
    required this.adjustmentsCount,
    this.note,
    this.openedAt,
    this.closedByName,
    this.closedAt,
    this.cancelReason,
  });

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  bool get isCancelled => status == 'cancelled';

  factory InventoryCountSummary.fromJson(Map<String, dynamic> json) =>
      InventoryCountSummary(
        id: json['id']?.toString() ?? '',
        locationId: json['location_id']?.toString() ?? '',
        locationName: json['location_name']?.toString() ?? '',
        status: json['status']?.toString() ?? 'open',
        note: json['note']?.toString(),
        openedByName: json['opened_by_name']?.toString() ?? '',
        openedAt: DateTime.tryParse(json['opened_at']?.toString() ?? ''),
        closedByName: json['closed_by_name']?.toString(),
        closedAt: DateTime.tryParse(json['closed_at']?.toString() ?? ''),
        cancelReason: json['cancel_reason']?.toString(),
        linesCount: (json['lines_count'] as num?)?.toInt() ?? 0,
        adjustmentsCount: (json['adjustments_count'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, status, linesCount, adjustmentsCount];
}

/// A batch that has been counted in a session.
class InventoryCountLine extends Equatable {
  final String batchId;
  final String batchNumber;
  final String productName;
  final DateTime? expiryDate;
  final String batchStatus;
  final int countedQty;

  /// What the system held at the moment of the count.
  final int expectedQty;

  /// `countedQty - expectedQty`: what closing the session will adjust.
  final int variance;
  final String countedByName;

  const InventoryCountLine({
    required this.batchId,
    required this.batchNumber,
    required this.productName,
    required this.batchStatus,
    required this.countedQty,
    required this.expectedQty,
    required this.variance,
    required this.countedByName,
    this.expiryDate,
  });

  factory InventoryCountLine.fromJson(Map<String, dynamic> json) =>
      InventoryCountLine(
        batchId: json['batch_id']?.toString() ?? '',
        batchNumber: json['batch_number']?.toString() ?? '',
        productName: json['product_name']?.toString() ?? '',
        expiryDate: DateTime.tryParse(json['expiry_date']?.toString() ?? ''),
        batchStatus: json['batch_status']?.toString() ?? 'active',
        countedQty: (json['counted_qty'] as num?)?.toInt() ?? 0,
        expectedQty: (json['expected_qty'] as num?)?.toInt() ?? 0,
        variance: (json['variance'] as num?)?.toInt() ?? 0,
        countedByName: json['counted_by_name']?.toString() ?? '',
      );

  @override
  List<Object?> get props => [batchId, countedQty, expectedQty];
}

/// A batch the system says is at the counted place but nobody has counted.
class InventoryUncounted extends Equatable {
  final String batchId;
  final String batchNumber;
  final String productName;
  final DateTime? expiryDate;
  final String batchStatus;
  final int systemQty;

  const InventoryUncounted({
    required this.batchId,
    required this.batchNumber,
    required this.productName,
    required this.batchStatus,
    required this.systemQty,
    this.expiryDate,
  });

  factory InventoryUncounted.fromJson(Map<String, dynamic> json) =>
      InventoryUncounted(
        batchId: json['batch_id']?.toString() ?? '',
        batchNumber: json['batch_number']?.toString() ?? '',
        productName: json['product_name']?.toString() ?? '',
        expiryDate: DateTime.tryParse(json['expiry_date']?.toString() ?? ''),
        batchStatus: json['batch_status']?.toString() ?? 'active',
        systemQty: (json['system_qty'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [batchId, systemQty];
}

/// A session with its counted lines and, while it is open, what is left to
/// count.
class InventoryCountDetail extends Equatable {
  final InventoryCountSummary summary;
  final List<InventoryCountLine> lines;
  final List<InventoryUncounted> uncounted;

  const InventoryCountDetail({
    required this.summary,
    required this.lines,
    required this.uncounted,
  });

  factory InventoryCountDetail.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
        raw is List
        ? raw
              .whereType<Map>()
              .map((e) => parse(e.cast<String, dynamic>()))
              .toList()
        : <T>[];

    final summary = json['summary'];
    if (summary is! Map) throw const FormatException('Réponse invalide.');
    return InventoryCountDetail(
      summary: InventoryCountSummary.fromJson(summary.cast<String, dynamic>()),
      lines: list(json['lines'], InventoryCountLine.fromJson),
      uncounted: list(json['uncounted'], InventoryUncounted.fromJson),
    );
  }

  @override
  List<Object?> get props => [summary, lines, uncounted];
}
