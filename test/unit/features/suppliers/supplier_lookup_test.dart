// Suppliers: the list is complete across pages, and one supplier is read by id
// (never found by scanning a list), so a supplier beyond the first page or
// reached by a deep link opens.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/cache/cache.dart';
import 'package:steriymed_mobile/features/suppliers/data/datasources/supplier_remote_datasource.dart';
import 'package:steriymed_mobile/features/suppliers/data/repositories/supplier_repository.dart';

class _Server implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object? Function(RequestOptions options)? answer;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(answer!(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _supplier(String id) => {
  'id': id,
  'name': 'Fournisseur $id',
  'email': null,
  'phone': null,
  'address': null,
};

void main() {
  late _Server server;
  late SupplierRemoteDatasource datasource;

  setUp(() {
    server = _Server();
    datasource = SupplierRemoteDatasource(
      Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))
        ..httpClientAdapter = server,
    );
  });

  test('lists every page of suppliers', () async {
    server.answer = (o) => o.queryParameters['cursor'] == null
        ? {
            'data': [_supplier('1'), _supplier('2')],
            'meta': {'next_cursor': 'next'},
          }
        : {
            'data': [_supplier('3')],
            'meta': {'next_cursor': null},
          };

    final suppliers = await datasource.list();

    expect(suppliers.map((s) => s.id), ['1', '2', '3']);
    expect(server.requests, hasLength(2));
  });

  test('show reads ONE supplier by id (flat body)', () async {
    server.answer = (_) => _supplier('beyond-page-one');

    final supplier = await datasource.show('beyond-page-one');

    expect(supplier.id, 'beyond-page-one');
    expect(server.requests.single.path, '/v1/suppliers/beyond-page-one');
    expect(server.requests.single.method, 'GET');
  });

  test('show also accepts a wrapped {data: ...} body', () async {
    server.answer = (_) => {'data': _supplier('42')};

    expect((await datasource.show('42')).id, '42');
  });

  test(
    'the repository reads the supplier from the server, not from the list',
    () async {
      server.answer = (_) => _supplier('7');
      final repo = SupplierRepository(datasource, AppCache());

      final supplier = await repo.show('7');

      expect(supplier.name, 'Fournisseur 7');
      expect(server.requests.single.path, '/v1/suppliers/7');
    },
  );
}
