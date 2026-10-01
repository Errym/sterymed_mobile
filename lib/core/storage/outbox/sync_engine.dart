import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../errors/api_exception.dart';
import '../../errors/error_mapper.dart';
import '../../utils/idempotency_key.dart';
import '../session_store.dart';
import 'outbox_item.dart';
import 'outbox_operation.dart';
import 'outbox_status.dart';
import 'outbox_store.dart';
import 'sync_result.dart';

class OperationAttempt {
  final OutboxItem item;
  final dynamic data;
  final ApiException? error;
  final bool confirmed;
  const OperationAttempt(
    this.item, {
    this.data,
    this.error,
    this.confirmed = false,
  });
}

/// All callers (online, reconnect, manual retry) share this serialized worker.
class SyncEngine {
  final OutboxStore _store;
  final Dio _dio;
  final SessionStore? _session;
  final void Function()? _onConfirmed;
  final DateTime Function() _now;
  Future<void> _tail = Future<void>.value();
  final Map<String, Future<OperationAttempt>> _inFlight = {};
  int _busy = 0;

  SyncEngine(
    this._store,
    this._dio, {
    this._session,
    this._onConfirmed,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  bool get isFlushing => _busy > 0;
  bool get canSend => _session == null || _session.canSend;

  Future<T> _serialized<T>(Future<T> Function() action) {
    _busy++;
    final next = _tail.then((_) => action()).whenComplete(() => _busy--);
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<OperationAttempt> submit({
    required OutboxOperation operation,
    required String endpoint,
    required Map<String, dynamic> payload,
    required String resourceKey,
    required bool online,
    bool requireOnline = false,
  }) {
    final owner = _store.currentOwner;
    final generation = _session?.generation;
    final body = jsonEncode(payload);
    final intent = jsonEncode([owner, operation.name, endpoint, body]);
    final existing = _inFlight[intent];
    if (existing != null) return existing;
    final pending = _serialized(() async {
      if (!_store.available ||
          (_session != null &&
              (generation != _session.generation || !canSend))) {
        throw const ApiException(
          code: 'session_validation_required',
          message: 'Vérifiez votre session avant d’enregistrer cette action.',
        );
      }
      if (requireOnline && !online) {
        throw const ApiException(
          code: 'network_error',
          message:
              'Une connexion est nécessaire pour cette décision. Votre saisie est conservée.',
        );
      }
      // Reopening an unresolved intent must not manufacture a fresh replay key.
      for (final item in _store.all()) {
        if (item.resourceKey != resourceKey) continue;
        if (item.endpoint == endpoint &&
            item.encodedPayload == body &&
            item.status == OutboxStatus.pending) {
          return OperationAttempt(item);
        }
        throw const ApiException(
          code: 'operation_unresolved',
          message:
              'Une action sur ce dossier attend une vérification dans la file de synchronisation.',
        );
      }
      final item = OutboxItem(
        id: generateIdempotencyKey(),
        ownerScope: owner,
        operation: operation,
        endpoint: endpoint,
        method: 'POST',
        payload: (jsonDecode(body) as Map).cast<String, dynamic>(),
        body: body,
        idempotencyKey: generateIdempotencyKey(),
        createdAt: _now().toUtc(),
        resourceKey: resourceKey,
        requiresReviewBeforeReplay: requireOnline,
      );
      await _store.enqueue(item);
      if (!online) return OperationAttempt(item);
      // An earlier unresolved command for this resource must finish first.
      if (_store.all().any(
        (other) => other.id != item.id && other.resourceKey == resourceKey,
      )) {
        return OperationAttempt(item);
      }
      return _send(item, generation: generation);
    });
    _inFlight[intent] = pending;
    unawaited(
      pending.then<void>(
        (_) {
          _inFlight.remove(intent);
        },
        onError: (Object _, StackTrace __) {
          _inFlight.remove(intent);
        },
      ),
    );
    return pending;
  }

  Future<int> flush() => _serialized(() async {
    if (!canSend) return 0;
    final generation = _session?.generation;
    final blocked = <String>{};
    var confirmed = 0;
    for (var item in _store.all()) {
      if (!canSend || generation != _session?.generation) break;
      final resource = item.resourceKey ?? item.endpoint;
      if (blocked.contains(resource)) continue;
      if (item.status == OutboxStatus.authBlocked) {
        item = item.copyWith(status: OutboxStatus.pending);
        await _store.update(item);
      }
      if (item.status == OutboxStatus.syncing) {
        // A killed sender may have committed. Never presume it failed.
        item = item.copyWith(
          status: OutboxStatus.unknownOutcome,
          lastError: 'Envoi interrompu : vérification du résultat nécessaire.',
        );
        await _store.update(item);
      }
      if (item.status != OutboxStatus.pending ||
          item.requiresReviewBeforeReplay ||
          item.nextAttemptAt != null && _now().isBefore(item.nextAttemptAt!)) {
        blocked.add(resource);
        continue;
      }
      final attempt = await _send(item, generation: generation);
      if (attempt.confirmed) {
        confirmed++;
      } else {
        blocked.add(resource);
      }
    }
    return confirmed;
  });

  Future<OperationAttempt> _send(OutboxItem item, {int? generation}) async {
    if (!canSend || generation != _session?.generation) {
      return OperationAttempt(item);
    }
    if (item.firstAttemptAt != null &&
        _now().difference(item.firstAttemptAt!) >= const Duration(hours: 23)) {
      final expired = item.copyWith(
        status: OutboxStatus.unknownOutcome,
        lastError:
            'Fenêtre de rejeu dépassée. Vérifiez le résultat avant toute nouvelle action.',
      );
      await _store.update(expired);
      return OperationAttempt(expired);
    }
    final sending = item.copyWith(
      status: OutboxStatus.syncing,
      firstAttemptAt: item.firstAttemptAt ?? _now().toUtc(),
      retryCount: item.retryCount + 1,
      clearNextAttempt: true,
      clearError: true,
    );
    await _store.update(sending);
    try {
      final response = await _dio.request(
        item.endpoint,
        data: item.encodedPayload,
        options: Options(
          method: item.method,
          contentType: Headers.jsonContentType,
          headers: {'Idempotency-Key': item.idempotencyKey},
          extra: {
            'operation_owner': item.ownerScope,
            'session_generation': generation,
            'durable_operation': true,
          },
        ),
      );
      if (generation != _session?.generation) return OperationAttempt(sending);
      final raw = response.data;
      final record =
          item.operation == OutboxOperation.stockTransfer && raw is Map
          ? raw['debit']
          : raw;
      if (record is! Map ||
          record['id'] == null ||
          record['id'].toString().isEmpty) {
        throw const ApiException(
          code: 'invalid_confirmation',
          message:
              'Réponse reçue illisible. Vérifiez le résultat avant de réessayer.',
        );
      }
      await _store.remove(item.id);
      _onConfirmed?.call();
      return OperationAttempt(sending, data: response.data, confirmed: true);
    } catch (error) {
      if (generation != _session?.generation) return OperationAttempt(sending);
      final api = error is DioException
          ? ErrorMapper.fromDio(error)
          : error is ApiException
          ? error
          : const ApiException(
              code: 'unknown',
              message: 'Résultat de l’envoi à vérifier.',
            );
      final statusCode = api.statusCode;
      final status =
          api.isUnauthenticated || api.code == 'session_validation_required'
          ? OutboxStatus.authBlocked
          : api.isForbidden
          ? OutboxStatus.permissionDenied
          : api.isConflict
          ? OutboxStatus.conflict
          : api.isValidation || statusCode == 400 || statusCode == 404
          ? OutboxStatus.validationFailed
          : api.isRateLimited && sending.retryCount < 5
          ? OutboxStatus.pending
          : OutboxStatus.unknownOutcome;
      final retryAfter = error is DioException
          ? int.tryParse(error.response?.headers.value('retry-after') ?? '')
          : null;
      final delay = (retryAfter ?? 30 * sending.retryCount).clamp(1, 3600);
      final updated = sending.copyWith(
        status: status,
        lastError: api.message,
        nextAttemptAt: status == OutboxStatus.pending
            ? _now().add(Duration(seconds: delay))
            : null,
      );
      await _store.update(updated);
      // Unknown results need authoritative reconciliation. The reviewed backend
      // can commit before its cache records a key; blind retries are unsafe.
      return OperationAttempt(updated, error: api);
    }
  }

  Future<SyncResult> retryOne(String id) => _serialized(() async {
    final item = _store.find(id);
    if (item == null || !canSend) return SyncResult.error;
    // No override for unknown/expired/validation/conflict operations.
    if (item.status != OutboxStatus.pending &&
        item.status != OutboxStatus.authBlocked) {
      return SyncResult.manualReview;
    }
    if (item.requiresReviewBeforeReplay ||
        item.nextAttemptAt != null && _now().isBefore(item.nextAttemptAt!)) {
      return SyncResult.manualReview;
    }
    final result = await _send(item, generation: _session?.generation);
    return result.confirmed ? SyncResult.success : SyncResult.manualReview;
  });
}
