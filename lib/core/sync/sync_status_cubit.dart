import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../lifecycle/app_lifecycle_observer.dart';
import '../storage/session_store.dart';
import '../storage/outbox/outbox_store.dart';
import '../storage/outbox/outbox_status.dart';
import '../storage/outbox/outbox_operation.dart';
import '../storage/outbox/sync_engine.dart';
import 'connectivity_service.dart';
import 'sync_status.dart';

class SyncStatusCubit extends Cubit<SyncStatus> {
  final OutboxStore _store;
  final SyncEngine _engine;
  final ConnectivityService _connectivity;
  final SessionStore? _session;
  final Future<bool> Function()? _refreshSession;
  final bool observeLifecycle;
  StreamSubscription<bool>? _sub;
  StreamSubscription<dynamic>? _storeSub;
  StreamSubscription<int>? _sessionSub;
  Timer? _timer;
  AppLifecycleObserver? _observer;
  bool _started = false;
  bool _checking = false;

  SyncStatusCubit({
    required this._store,
    required this._engine,
    required this._connectivity,
    this._session,
    this._refreshSession,
    this.observeLifecycle = false,
  }) : super(const SyncStatus());
  bool get isFlushing => _engine.isFlushing;

  Future<OperationAttempt> submit({
    required OutboxOperation operation,
    required String endpoint,
    required Map<String, dynamic> payload,
    required String resourceKey,
    required bool online,
    bool requireOnline = false,
  }) async {
    try {
      final work = _engine.submit(
        operation: operation,
        endpoint: endpoint,
        payload: payload,
        resourceKey: resourceKey,
        online: online,
        requireOnline: requireOnline,
      );
      _refresh(online: online);
      return await work;
    } finally {
      _refresh();
    }
  }

  Future<void> start() async {
    if (_started || isClosed) return;
    _started = true;
    _sub = _connectivity.onStatusChange.listen((online) {
      _refresh(online: online);
      unawaited(_checkAndFlush());
    });
    if (_session != null) {
      _storeSub = _store.changes.listen((_) => _refresh());
      _sessionSub = _session.changes.listen((_) {
        _refresh();
        if (_session.canSend) unawaited(_flushIfOnline(state.online));
      });
      _timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(_checkAndFlush()),
      );
    }
    if (observeLifecycle) {
      _observer = AppLifecycleObserver(
        onResume: () => unawaited(_checkAndFlush(forceRefresh: true)),
      );
      WidgetsBinding.instance.addObserver(_observer!);
    }
    final online = await _connectivity.isConnected;
    if (isClosed) return;
    _refresh(online: online);
    await _flushIfOnline(online);
  }

  Future<void> _checkAndFlush({bool forceRefresh = false}) async {
    if (_checking || isClosed) return;
    _checking = true;
    try {
      final online = await _connectivity.isConnected;
      if (isClosed) return;
      _refresh(online: online);
      if (online &&
          _session?.hasSession == true &&
          (forceRefresh || !_session!.permissionsFresh) &&
          _refreshSession != null) {
        await _refreshSession();
      }
      await _flushIfOnline(online);
    } catch (_) {
      // Preserve the session and queue; the next reconnect/resume can retry.
    } finally {
      _checking = false;
      _refresh();
    }
  }

  Future<void> _flushIfOnline(bool online) async {
    if (!online || isClosed || _engine.isFlushing) return;
    try {
      final flushed = _engine.flush();
      _refresh(online: true);
      await flushed;
    } finally {
      _refresh();
    }
  }

  void _refresh({bool? online}) {
    if (isClosed) return;
    final scoped = _session != null;
    final items = scoped ? _store.all() : null;
    final waiting = items
        ?.where(
          (i) =>
              i.status == OutboxStatus.pending ||
              i.status == OutboxStatus.syncing,
        )
        .length;
    final blocked = items
        ?.where(
          (i) =>
              i.status != OutboxStatus.pending &&
              i.status != OutboxStatus.syncing &&
              i.status != OutboxStatus.synced,
        )
        .length;
    emit(
      state.copyWith(
        online: online ?? state.online,
        pendingCount: waiting ?? _store.pendingCount,
        manualReviewCount: blocked ?? _store.manualReview().length,
        isSyncing: _engine.isFlushing,
        localRecoveryRequired: scoped && _store.recoveryRequired,
        quarantinedCount: scoped ? _store.quarantineCount : 0,
      ),
    );
  }

  Future<void> refreshNow() async => _refresh();
  @override
  Future<void> close() async {
    _timer?.cancel();
    if (_observer != null) WidgetsBinding.instance.removeObserver(_observer!);
    await _sub?.cancel();
    await _storeSub?.cancel();
    await _sessionSub?.cancel();
    await _connectivity.dispose();
    return super.close();
  }
}
