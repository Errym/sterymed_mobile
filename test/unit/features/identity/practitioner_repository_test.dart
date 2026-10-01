// The practitioner list comes from the server (the same rule that validates a
// create/update), across every page, and is cached briefly.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/cache/cache.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/identity/data/repositories/practitioner_repository.dart';

class _Server implements HttpClientAdapter {
  int calls = 0;
  final cursors = <Object?>[];
  final pages = <String?, Object>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    final cursor = options.queryParameters['cursor'] as String?;
    cursors.add(cursor);
    final answer = pages[cursor] ?? 500;
    return ResponseBody.fromString(
      jsonEncode(
        answer is int
            ? {
                'error': {'code': 'SERVER_ERROR', 'message': 'boom'},
              }
            : answer,
      ),
      answer is int ? answer : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object> _page(List<Map<String, Object?>> rows, {String? next}) => {
  'data': rows,
  'meta': {'next_cursor': next},
};

void main() {
  late _Server server;
  late PractitionerRepository repo;

  setUp(() {
    server = _Server();
    repo = PractitionerRepository(
      Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))
        ..httpClientAdapter = server,
      AppCache(),
    );
  });

  Map<String, Object?> person(String id, String name, String role) => {
    'id': id,
    'name': name,
    'role': role,
  };

  test('returns every page, keeping names and roles', () async {
    server.pages[null] = _page([person('1', 'Dr A', 'owner')], next: 'c2');
    server.pages['c2'] = _page([person('2', 'Dr B', 'practitioner')]);

    final people = await repo.list();

    expect(people.map((p) => p.name), ['Dr A', 'Dr B']);
    expect(people.last.role, 'practitioner');
    expect(server.cursors, [null, 'c2']);
  });

  test('is cached, and forceRefresh asks the server again', () async {
    server.pages[null] = _page([person('1', 'Dr A', 'owner')]);

    await repo.list();
    await repo.list();
    expect(server.calls, 1);

    await repo.list(forceRefresh: true);
    expect(server.calls, 2);
  });

  test(
    'a server error is surfaced as an ApiException and not cached',
    () async {
      await expectLater(repo.list(), throwsA(isA<ApiException>()));

      server.pages[null] = _page([person('1', 'Dr A', 'owner')]);
      final people = await repo.list();
      expect(people, hasLength(1));
    },
  );
}
