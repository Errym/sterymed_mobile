import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/outbox/outbox_store.dart';
import '../storage/outbox/sync_engine.dart';
import 'connectivity_service.dart';
import 'sync_status.dart';

class SyncStatusCubit extends Cubit<SyncStatus> {
  final OutboxStore _store;
  final SyncEngine _engine;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _sub;

  SyncStatusCubit({
    required OutboxStore store,
    required SyncEngine engine,
    required ConnectivityService connectivity,
  })  : _store = store,
        _engine = engine,
        _connectivity = connectivity,
        super(const SyncStatus());

  Future<void> start() async {
    final online = await _connectivity.isConnected;
    _refresh(online: online);
    await _flushIfOnline(online);
    _sub = _connectivity.onStatusChange.listen((online) async {
      _refresh(online: online);
      await _flushIfOnline(online);
    });
  }

  Future<void> _flushIfOnline(bool online) async {
    if (!online) return;
    await _engine.flush();
    _refresh(online: true);
  }

  void _refresh({bool? online}) {
    emit(state.copyWith(
      online: online ?? state.online,
      pendingCount: _store.pendingCount,
      manualReviewCount: _store.manualReview().length,
    ));
  }

  Future<void> refreshNow() async => _refresh();

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _connectivity.dispose();
    return super.close();
  }
}
