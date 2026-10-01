import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:steriymed_mobile/core/cache/cache.dart';
import 'package:steriymed_mobile/core/network/interceptors/auth_interceptor.dart';
import 'package:steriymed_mobile/core/network/interceptors/error_interceptor.dart';
import 'package:steriymed_mobile/core/storage/key_value_store.dart';
import 'package:steriymed_mobile/core/storage/secure_storage.dart';
import 'package:steriymed_mobile/core/storage/session_store.dart';
import 'package:steriymed_mobile/core/storage/token_storage.dart';
import 'package:steriymed_mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:steriymed_mobile/features/auth/data/repositories/auth_repository.dart';

class MemorySecure extends SecureStorage {
  final values = <String, String>{};
  Future<void> Function()? beforeWrite;
  @override Future<String?> read(String key) async => values[key];
  @override Future<void> write(String key, String value) async {
    await beforeWrite?.call(); values[key] = value;
  }
  @override Future<void> delete(String key) async { values.remove(key); }
}
class DelayedLogout extends AuthRemoteDatasource {
  DelayedLogout() : super(Dio());
  final ended = Completer<void>();
  String? revokedToken;
  @override Future<void> logout({String? token}) { revokedToken = token; return ended.future; }
}
class DelayedAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  final answer = Completer<ResponseBody>();
  RequestOptions? options;
  @override Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    this.options = options; started.complete(); return answer.future;
  }
  @override void close({bool force = false}) {}
}
Future<void> login(SessionStore session, String name, {String? role}) async {
  final generation = session.beginReplacement();
  await session.commit(generation: generation, token: 'token-$name',
    user: {'id': name, 'permissions': ['cycles.view'], if (role != null) 'role': role},
    tenant: {'id': 'clinic-$name'}, fallbackRole: role);
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('session envelope persists owner and token atomically; restart requires validation', () async {
    final secure = MemorySecure(); final session = SessionStore(secure);
    await login(session, 'A', role: 'owner');
    final restored = SessionStore(secure); await restored.load();
    expect(restored.userId, 'A'); expect(restored.token, 'token-A');
    expect(restored.canSend, isFalse);
    await restored.set(user: {'id': 'A', 'permissions': ['cycles.view']}, tenant: {'id': 'clinic-A'});
    expect(restored.canSend, isTrue); expect(restored.role, isNull);
  });
  test('corrupt and foreign-environment sessions stay preserved and cannot authenticate', () async {
    final secure = MemorySecure(); secure.values[SessionStore.recordKey] = '{broken';
    final session = SessionStore(secure); await session.load();
    expect(session.hasSession, isFalse); expect(secure.values[SessionStore.recordKey], '{broken');
    await login(session, 'A');
    final record = jsonDecode(secure.values[SessionStore.recordKey]!) as Map<String, dynamic>;
    record['api'] = 'https://another.invalid/api'; secure.values[SessionStore.recordKey] = jsonEncode(record);
    final other = SessionStore(secure); await other.load(); expect(other.hasSession, isFalse);
  });
  test('late secure write cannot replace a newer session', () async {
    final secure = MemorySecure(); final session = SessionStore(secure);
    final gate = Completer<void>(); var once = true;
    secure.beforeWrite = () async { if (once) { once = false; await gate.future; } };
    final first = login(session, 'A');
    await Future<void>.delayed(Duration.zero);
    final second = login(session, 'B');
    gate.complete(); await Future.wait([first, second]);
    expect(session.userId, 'B');
    final restored = SessionStore(secure); await restored.load(); expect(restored.userId, 'B');
  });
  test('logout clears immediately and late revocation cannot clear login B', () async {
    final secure = MemorySecure(); final session = SessionStore(secure); await login(session, 'A');
    final remote = DelayedLogout();
    final repo = AuthRepository(remote: remote, sessionStore: session, tokenStorage: TokenStorage(secure, session: session));
    final logout = repo.logout(); expect(session.hasSession, isFalse);
    await Future<void>.delayed(Duration.zero); await login(session, 'B');
    remote.ended.completeError(StateError('network unavailable')); await logout;
    expect(remote.revokedToken, 'token-A'); expect(session.userId, 'B');
  });
  for (final status in [200, 401]) {
    test('late HTTP $status from A is fenced after B logs in', () async {
      final secure = MemorySecure(); final session = SessionStore(secure); await login(session, 'A');
      final adapter = DelayedAdapter(); var expired = false;
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))..httpClientAdapter = adapter;
      dio.interceptors.addAll([AuthInterceptor(TokenStorage(secure, session: session), session: session),
        ErrorInterceptor(onUnauthenticated: () => expired = true)]);
      final request = dio.get('/v1/me');
      final assertion = expectLater(request, throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.cancel)));
      await adapter.started.future; await login(session, 'B');
      adapter.answer.complete(ResponseBody.fromString('{}', status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]}));
      await assertion; expect(expired, isFalse); expect(session.userId, 'B');
      expect(adapter.options!.headers['Authorization'], 'Bearer token-A'); dio.close();
    });
  }
  test('cache separates owners and mismatched model types', () {
    String? owner = 'A'; final cache = AppCache(ownerScope: () => owner);
    cache.put('devices', <String>['A']); expect(cache.get<List<int>>('devices'), isNull);
    owner = 'B'; expect(cache.get<List<String>>('devices'), isNull);
    cache.put('devices', <String>['B']); owner = null; expect(cache.get<List<String>>('devices'), isNull);
  });
  group('encrypted owner-scoped persistence', () {
    late Directory directory;
    setUp(() async { directory = await Directory.systemTemp.createTemp('clinic-storage-'); Hive.init(directory.path); });
    tearDown(() async { await Hive.close(); await directory.delete(recursive: true); });
    test('legacy bytes are quarantined and never adopted; drafts survive restart with their owner', () async {
      final legacy = await Hive.openBox('drafts'); await legacy.put('draft', 'legacy-secret'); await legacy.close();
      final secure = MemorySecure(); String? owner = 'A';
      final store = await KeyValueStore.open('drafts', secure: secure, ownerScope: () => owner);
      expect(store.quarantineCount, 1); expect(store.get('draft'), isNull);
      await store.set('draft', 'patient-A-secret'); owner = 'B'; expect(store.get('draft'), isNull);
      await store.set('draft', 'patient-B-secret'); owner = 'A'; expect(store.get('draft'), 'patient-A-secret');
      await Hive.close();
      final bytes = await File('${directory.path}/drafts.v2.hive').readAsBytes();
      expect(utf8.decode(bytes, allowMalformed: true), isNot(contains('patient-A-secret')));
      final restarted = await KeyValueStore.open('drafts', secure: secure, ownerScope: () => owner);
      expect(restarted.get('draft'), 'patient-A-secret'); expect(restarted.quarantineCount, 1);
    });
    test('key loss blocks access without replacing key or changing encrypted bytes', () async {
      final secure = MemorySecure();
      final store = await KeyValueStore.open('drafts', secure: secure, ownerScope: () => 'A');
      await store.set('draft', 'preserve me'); await Hive.close();
      final file = File('${directory.path}/drafts.v2.hive'); final before = await file.readAsBytes();
      secure.values.clear();
      final locked = await KeyValueStore.open('drafts', secure: secure, ownerScope: () => 'A');
      expect(locked.recoveryRequired, isTrue); expect(locked.get('draft'), isNull);
      await expectLater(locked.set('draft', 'replacement'), throwsStateError);
      expect(await file.readAsBytes(), before); expect(secure.values, isEmpty);
    });
  });
}
