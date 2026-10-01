import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_store.dart';
import 'package:steriymed_mobile/core/storage/outbox/sync_engine.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/core/sync/sync_status_cubit.dart';
import '../mocks/mock_connectivity.dart';

class QueueAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Future<void> Function(RequestOptions)? beforeReply;
  int status = 200;
  DioExceptionType? failure;
  dynamic data = <String, dynamic>{'id': 'confirmed-record'};
  int? retryAfter;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await beforeReply?.call(options);
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (retryAfter != null) 'retry-after': ['$retryAfter'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class QueueHarness {
  final Directory directory;
  final OutboxStore store;
  final Dio dio;
  final QueueAdapter adapter;
  final SyncEngine engine;
  final SyncStatusCubit sync;
  final MockConnectivityService connectivity;
  bool online = true;
  QueueHarness._(
    this.directory,
    this.store,
    this.dio,
    this.adapter,
    this.engine,
    this.sync,
    this.connectivity,
  );
  static Future<QueueHarness> create({
    DateTime Function()? now,
    SessionStore? session,
    String Function()? owner,
    void Function()? onConfirmed,
  }) async {
    final directory = await Directory.systemTemp.createTemp('durable-queue-');
    Hive.init(directory.path);
    final box = await Hive.openBox<dynamic>('queue');
    final store = OutboxStore(
      box,
      ownerScope:
          owner ??
          (session != null ? () => session.scopeKey : () => 'fixture/A'),
    );
    final adapter = QueueAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))
      ..httpClientAdapter = adapter;
    final engine = SyncEngine(
      store,
      dio,
      session: session,
      onConfirmed: onConfirmed,
      now: now,
    );
    final connectivity = MockConnectivityService();
    when(() => connectivity.dispose()).thenAnswer((_) async {});
    final sync = SyncStatusCubit(
      store: store,
      engine: engine,
      connectivity: connectivity,
    );
    final harness = QueueHarness._(
      directory,
      store,
      dio,
      adapter,
      engine,
      sync,
      connectivity,
    );
    when(
      () => connectivity.isConnected,
    ).thenAnswer((_) async => harness.online);
    return harness;
  }

  /// Waits until the first request reaches the adapter, then yields briefly so
  /// any (incorrect) second request would also have been recorded. Deterministic
  /// replacement for a fixed sleep, which raced the engine under load.
  Future<void> untilRequested() async {
    for (var i = 0; i < 500 && adapter.requests.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }

  Future<void> close() async {
    await sync.close();
    dio.close();
    await Hive.close();
    await directory.delete(recursive: true);
  }
}
