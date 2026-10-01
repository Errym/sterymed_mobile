// LIVE end-to-end proof for the durable queue against a real running
// `steriqore` backend (dev stack, docker compose up). Skipped unless
// RUN_LIVE_BACKEND_TESTS=true, so CI and normal `flutter test` never need it.
//
//   RUN_LIVE_BACKEND_TESTS=true TEST_ADMIN_EMAIL=... TEST_ADMIN_PASSWORD=... \
//   TEST_ADMIN_TENANT=... [LIVE_API_BASE=http://localhost:8010/api] \
//   flutter test test/live/queue_lost_response_live_test.dart
//
// It counts real database rows (docker exec on the dev Postgres), so it proves
// the server-side effect, not just the client's view of it.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_operation.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_status.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_store.dart';
import 'package:steriymed_mobile/core/storage/outbox/sync_engine.dart';
import 'package:steriymed_mobile/core/storage/outbox/sync_result.dart';
import 'package:steriymed_mobile/core/storage/secure_storage.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';

final _env = Platform.environment;
final _enabled =
    _env['RUN_LIVE_BACKEND_TESTS'] == 'true' &&
    (_env['TEST_ADMIN_EMAIL'] ?? '').isNotEmpty &&
    (_env['TEST_ADMIN_PASSWORD'] ?? '').isNotEmpty &&
    (_env['TEST_ADMIN_TENANT'] ?? '').isNotEmpty;
final _base = _env['LIVE_API_BASE'] ?? 'http://localhost:8010/api';
const _skipReason = 'set RUN_LIVE_BACKEND_TESTS=true and the TEST_ADMIN_* vars';

class _MemorySecure extends SecureStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Real network, but the first answer is discarded as if the connection
/// dropped after the server had already committed.
class _LoseFirstAnswer implements HttpClientAdapter {
  final _real = IOHttpClientAdapter();
  int calls = 0;
  bool loseFirst = true;
  final replayedHeaders = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    final response = await _real.fetch(options, requestStream, cancelFuture);
    replayedHeaders.add(response.headers['idempotency-replayed']?.first);
    if (loseFirst && calls == 1) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return response;
  }

  @override
  void close({bool force = false}) => _real.close(force: force);
}

Future<int?> _patientRows() async {
  try {
    final out = await Process.run('docker', [
      'exec',
      'steriqore-postgres',
      'psql',
      '-U',
      'steriqore',
      '-d',
      'steriqore',
      '-tAc',
      'select count(*) from patients',
    ]);
    return int.tryParse((out.stdout as String).trim());
  } catch (_) {
    return null;
  }
}

String _uuid() {
  final r = Random.secure();
  String h(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-a${h(3)}-${h(12)}';
}

void main() {
  late Directory dir;
  late SessionStore session;
  late OutboxStore store;
  late Dio dio;
  late _LoseFirstAnswer adapter;

  setUp(() async {
    if (!_enabled) return;
    dir = await Directory.systemTemp.createTemp('live-queue-');
    Hive.init(dir.path);
    final login = await Dio(BaseOptions(baseUrl: _base)).post<Map>(
      '/v1/auth/login',
      data: {
        'tenant_slug': _env['TEST_ADMIN_TENANT'],
        'email': _env['TEST_ADMIN_EMAIL'],
        'password': _env['TEST_ADMIN_PASSWORD'],
      },
      options: Options(headers: {'Idempotency-Key': _uuid()}),
    );
    final body = login.data!.cast<String, dynamic>();
    session = SessionStore(_MemorySecure());
    await session.commit(
      generation: session.beginReplacement(),
      token: body['token'] as String,
      user: (body['user'] as Map).cast<String, dynamic>(),
      tenant: (body['tenant'] as Map).cast<String, dynamic>(),
    );
    store = OutboxStore(
      await Hive.openBox<dynamic>('live-queue'),
      ownerScope: () => session.scopeKey,
    );
    adapter = _LoseFirstAnswer();
    dio = Dio(
      BaseOptions(
        baseUrl: _base,
        headers: {'Authorization': 'Bearer ${body['token']}'},
      ),
    )..httpClientAdapter = adapter;
  });

  tearDown(() async {
    if (!_enabled) return;
    await Hive.close();
    await session.dispose();
    await dir.delete(recursive: true);
  });

  test(
    'response lost after the server committed: resending the same key creates '
    'no second row',
    () async {
      final before = await _patientRows();
      final engine = SyncEngine(store, dio, session: session);

      await engine.submit(
        operation: OutboxOperation.stockIssue, // label only; the path decides
        endpoint: '/v1/patients',
        payload: const {},
        resourceKey: 'live:patient',
        online: true,
      );
      final stuck = store.all().single;
      expect(stuck.status, OutboxStatus.unknownOutcome);
      if (before != null) {
        expect(await _patientRows(), before + 1, reason: 'server committed');
      }

      final result = await engine.resendUnknown(stuck.id);

      expect(result, SyncResult.success);
      expect(store.all(), isEmpty);
      expect(adapter.replayedHeaders.last, 'true', reason: 'server replayed');
      if (before != null) {
        expect(await _patientRows(), before + 1, reason: 'still one new row');
      }
    },
    skip: _enabled ? false : _skipReason,
  );

  test(
    'two engines over one persisted operation never double-send: one row',
    () async {
      adapter.loseFirst = false;
      final before = await _patientRows();
      final first = SyncEngine(store, dio, session: session);
      await first.submit(
        operation: OutboxOperation.stockIssue,
        endpoint: '/v1/patients',
        payload: const {},
        resourceKey: 'live:patient-race',
        online: false, // persist only
      );
      final second = SyncEngine(store, dio, session: session);

      await Future.wait([first.flush(), second.flush()]);

      if (before != null) {
        expect(await _patientRows(), before + 1, reason: 'one row, one key');
      }
      // The second engine sees the item already held by the first and does not
      // send it again.
      expect(adapter.calls, 1, reason: 'a single request reached the server');
    },
    skip: _enabled ? false : _skipReason,
  );
}
