import 'dart:convert';
import 'outbox_operation.dart';
import 'outbox_status.dart';

/// The server keeps every tenant-scoped operation for 90 days
/// (`idempotency:prune`). Replays stop at 60 days so a client never resends a
/// key the server may already have forgotten.
const Duration kReplayWindow = Duration(days: 60);

class OutboxItem {
  final String? ownerScope;
  final int schemaVersion;
  final String? resourceKey;
  final String? body;
  final DateTime? firstAttemptAt;
  final DateTime? nextAttemptAt;
  final bool requiresReviewBeforeReplay;
  String get encodedPayload => body ?? jsonEncode(payload);
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
    this.ownerScope,
    this.schemaVersion = 2,
    this.resourceKey,
    this.body,
    this.firstAttemptAt,
    this.nextAttemptAt,
    this.requiresReviewBeforeReplay = false,
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
    DateTime? firstAttemptAt,
    DateTime? nextAttemptAt,
    bool clearNextAttempt = false,
    bool clearError = false,
    int? retryCount,
    OutboxStatus? status,
    String? lastError,
    bool? requiresReviewBeforeReplay,
  }) {
    return OutboxItem(
      ownerScope: ownerScope,
      schemaVersion: schemaVersion,
      resourceKey: resourceKey,
      body: encodedPayload,
      firstAttemptAt: firstAttemptAt ?? this.firstAttemptAt,
      nextAttemptAt: clearNextAttempt
          ? null
          : nextAttemptAt ?? this.nextAttemptAt,
      requiresReviewBeforeReplay:
          requiresReviewBeforeReplay ?? this.requiresReviewBeforeReplay,
      id: id,
      operation: operation,
      endpoint: endpoint,
      method: method,
      payload: payload,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }

  /// A user may deliberately re-send an unknown-outcome item with its
  /// original key, but only while the server can still recognise that key.
  bool canResend(DateTime now) =>
      status == OutboxStatus.unknownOutcome &&
      firstAttemptAt != null &&
      now.difference(firstAttemptAt!) < kReplayWindow;

  Map<String, dynamic> toJson() => {
    'ownerScope': ownerScope,
    'schemaVersion': schemaVersion,
    'resourceKey': resourceKey,
    'body': encodedPayload,
    'firstAttemptAt': firstAttemptAt?.toIso8601String(),
    'nextAttemptAt': nextAttemptAt?.toIso8601String(),
    'requiresReviewBeforeReplay': requiresReviewBeforeReplay,
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
    ownerScope: json['ownerScope'] as String?,
    schemaVersion: json['schemaVersion'] as int? ?? 1,
    resourceKey: json['resourceKey'] as String?,
    body: json['body'] as String?,
    firstAttemptAt: DateTime.tryParse(json['firstAttemptAt']?.toString() ?? ''),
    nextAttemptAt: DateTime.tryParse(json['nextAttemptAt']?.toString() ?? ''),
    requiresReviewBeforeReplay: json['requiresReviewBeforeReplay'] == true,
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
