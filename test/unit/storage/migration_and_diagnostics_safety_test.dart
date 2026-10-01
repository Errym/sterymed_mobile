// Phase 1 proofs: interrupted storage migration, upgrade with a pending
// legacy outbox item, and diagnostics that never carry secrets.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:steriymed_mobile/core/network/interceptors/logging_interceptor.dart';
import 'package:steriymed_mobile/core/storage/key_value_store.dart';
import 'package:steriymed_mobile/core/storage/outbox/outbox_store.dart';
import 'package:steriymed_mobile/core/storage/secure_storage.dart';

class _MemorySecure extends SecureStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _OkAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'ok': true}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('migration-safety-');
    Hive.init(directory.path);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'a crash mid-migration loses nothing and repeating it creates no duplicates',
    () async {
      final secure = _MemorySecure();
      // Legacy plaintext box holds two records.
      final legacy = await Hive.openBox('drafts');
      await legacy.put('a', 'draft-a');
      await legacy.put('b', 'draft-b');
      await legacy.close();

      // First open migrates everything, then we simulate the crash window by
      // restoring the legacy bytes as if the delete had never been flushed.
      final first = await KeyValueStore.open(
        'drafts',
        secure: secure,
        ownerScope: () => 'A',
      );
      expect(first.quarantineCount, 2);
      await Hive.close();
      final stale = await Hive.openBox('drafts');
      await stale.put('a', 'draft-a');
      await stale.put('b', 'draft-b');
      await stale.close();

      // Second open must be idempotent: same two quarantined records, legacy
      // box emptied, nothing adopted by the current owner.
      final second = await KeyValueStore.open(
        'drafts',
        secure: secure,
        ownerScope: () => 'A',
      );
      expect(second.quarantineCount, 2);
      expect(second.get('a'), isNull);
      await Hive.close();
      final after = await Hive.openBox('drafts');
      expect(after.isEmpty, isTrue);
    },
  );

  test(
    'upgrade with a pending legacy outbox item quarantines it: not replayed, '
    'not deleted, not assigned to the next login',
    () async {
      final secure = _MemorySecure();
      final legacy = await Hive.openBox('steriymed.outbox');
      await legacy.put('old-1', {
        'id': 'old-1',
        'operation': 'stockIssue',
        'endpoint': '/v1/stock-movements/issue',
        'method': 'POST',
        'payload': {'batch_id': 'b', 'qty': 1},
        'idempotencyKey': 'old-key',
        'createdAt': DateTime.utc(2026, 9, 1).toIso8601String(),
        'status': 'pending',
      });
      await legacy.close();

      var owner = 'clinic-A/user-1';
      final store = await OutboxStore.open(
        secure: secure,
        ownerScope: () => owner,
      );
      expect(store.quarantineCount, 1);
      expect(store.all(), isEmpty);
      expect(store.pending(), isEmpty);

      owner = 'clinic-B/user-2'; // next login on the same phone
      expect(store.all(), isEmpty);
      expect(store.quarantineCount, 1, reason: 'preserved for recovery');
    },
  );

  test('HTTP diagnostics never contain tokens, URLs, query strings or ids',
      () async {
    final lines = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    addTearDown(() => debugPrint = original);

    final dio = Dio(BaseOptions(baseUrl: 'https://clinic.example.invalid/api'))
      ..httpClientAdapter = _OkAdapter()
      ..interceptors.add(LoggingInterceptor());
    await dio.post<void>(
      '/v1/labels/LABEL-SECRET-123/usage?token=QUERY-SECRET',
      data: {'patient_id': 'PATIENT-SECRET', 'password': 'PASSWORD-SECRET'},
      options: Options(headers: {'Authorization': 'Bearer BEARER-SECRET'}),
    );

    expect(lines, isNotEmpty, reason: 'diagnostics must still be emitted');
    final joined = lines.join('\n');
    for (final secret in [
      'BEARER-SECRET',
      'QUERY-SECRET',
      'LABEL-SECRET-123',
      'PATIENT-SECRET',
      'PASSWORD-SECRET',
      'clinic.example.invalid',
      '/v1/labels',
    ]) {
      expect(joined, isNot(contains(secret)), reason: secret);
    }
    dio.close();
  });
}
