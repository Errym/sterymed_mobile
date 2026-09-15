import 'outbox_operation.dart';
import 'outbox_status.dart';

class OutboxItem {
  final String id;
  final OutboxOperation operation;
  final String endpoint;
  final String method;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final DateTime createdAt;
  final int retryCount;
  final OutboxStatus status;
  final String? lastError;

  const OutboxItem({
    required this.id,
    required this.operation,
    required this.endpoint,
    required this.method,
    required this.payload,
    required this.idempotencyKey,
    required this.createdAt,
    this.retryCount = 0,
    this.status = OutboxStatus.pending,
    this.lastError,
  });

  OutboxItem copyWith({
    int? retryCount,
    OutboxStatus? status,
    String? lastError,
  }) {
    return OutboxItem(
      id: id,
      operation: operation,
      endpoint: endpoint,
      method: method,
      payload: payload,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation.name,
    'endpoint': endpoint,
    'method': method,
    'payload': payload,
    'idempotencyKey': idempotencyKey,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'status': status.name,
    'lastError': lastError,
  };

  factory OutboxItem.fromJson(Map<String, dynamic> json) => OutboxItem(
    id: json['id'] as String,
    operation: OutboxOperation.values.firstWhere(
      (e) => e.name == json['operation'],
    ),
    endpoint: json['endpoint'] as String,
    method: json['method'] as String,
    payload: (json['payload'] as Map).cast<String, dynamic>(),
    idempotencyKey: json['idempotencyKey'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    retryCount: json['retryCount'] as int? ?? 0,
    status: OutboxStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => OutboxStatus.pending,
    ),
    lastError: json['lastError'] as String?,
  );
}
