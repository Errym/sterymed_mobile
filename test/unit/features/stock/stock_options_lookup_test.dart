// The stock pickers (batches, locations) come from the dedicated lookup
// endpoints: complete across pages, independent of stock rows, with a
// compatibility fallback only when the server has no such routes.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/stock/data/datasources/stock_remote_datasource.dart';

/// Answers each GET by path (+ cursor), and records every query it saw.
class _Server implements HttpClientAdapter {
  final queries = <String, List<Map<String, dynamic>>>{};
  final pages = <String, Map<String?, Object>>{}; // path -> cursor -> body|int
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    queries
        .putIfAbsent(path, () => [])
        .add(Map<String, dynamic>.from(options.queryParameters));
    final answer = pages[path]?[options.queryParameters['cursor']];
    if (answer == null || answer is int) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {'code': 'NOT_FOUND', 'message': 'nope'},
        }),
        (answer as int?) ?? 404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(answer),
      200,
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
  late StockRemoteDatasource datasource;

  setUp(() {
    server = _Server();
    datasource = StockRemoteDatasource(
      Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))
        ..httpClientAdapter = server,
    );
  });

  Map<String, Object?> loc(String id, String name, {String site = 'Cabinet'}) =>
      {'id': id, 'name': name, 'site_name': site, 'room_name': null};
  Map<String, Object?> batch(String id, String number, {int qty = 0}) => {
    'id': id,
    'batch_number': number,
    'product_name': 'Gants',
    'qty_on_hand': qty,
  };

  test(
    'an empty clinic still gets its locations (no stock required)',
    () async {
      server.pages['/v1/locations'] = {
        null: _page([loc('l1', 'Réserve'), loc('l2', 'Stérilisation')]),
      };
      server.pages['/v1/batches'] = {null: _page([])};

      final options = await datasource.listOptions();

      expect(options.locations.map((o) => o.id), ['l1', 'l2']);
      expect(options.batches, isEmpty);
      expect(options.locations.first.label, 'Réserve · Cabinet');
    },
  );

  test('follows the cursor across every page of both lookups', () async {
    server.pages['/v1/locations'] = {
      null: _page([loc('l1', 'A')], next: 'c2'),
      'c2': _page([loc('l2', 'B')], next: 'c3'),
      'c3': _page([loc('l3', 'C')]),
    };
    server.pages['/v1/batches'] = {
      null: _page([batch('b1', 'LOT-1', qty: 4)], next: 'p2'),
      'p2': _page([batch('b2', 'LOT-2')]),
    };

    final options = await datasource.listOptions();

    expect(options.locations.map((o) => o.id), ['l1', 'l2', 'l3']);
    expect(options.batches.map((o) => o.id), ['b1', 'b2']);
    expect(server.queries['/v1/locations'], hasLength(3));
    expect(server.queries['/v1/locations']![1]['cursor'], 'c2');
    expect(
      server.queries['/v1/locations']!.every((q) => q['limit'] == 100),
      isTrue,
    );
  });

  test(
    'batches are requested active-only and show the quantity on hand',
    () async {
      server.pages['/v1/locations'] = {null: _page([])};
      server.pages['/v1/batches'] = {
        null: _page([batch('b1', 'LOT-9', qty: 12), batch('b2', 'LOT-0')]),
      };

      final options = await datasource.listOptions();

      expect(server.queries['/v1/batches']!.single['status'], 'active');
      expect(
        options.batches.firstWhere((o) => o.id == 'b1').label,
        'Lot LOT-9 · Gants · 12 en stock',
      );
      expect(
        options.batches.firstWhere((o) => o.id == 'b2').label,
        'Lot LOT-0 · Gants · 0 en stock',
      );
    },
  );

  test(
    'a server without the lookup routes falls back to stock levels',
    () async {
      // /v1/locations and /v1/batches answer 404 (older backend).
      server.pages['/v1/stock-levels'] = {
        null: {
          'data': [
            {
              'id': 's1',
              'batch_id': 'b1',
              'batch_number': 'LOT-1',
              'expiry_date': null,
              'product_id': 'p1',
              'product_name': 'Gants',
              'product_reference': 'REF',
              'product_unit': 'box',
              'min_threshold': 1,
              'location_id': 'l1',
              'location_name': 'Réserve',
              'quantity': 3,
            },
          ],
          'meta': {'next_cursor': null},
        },
      };

      final options = await datasource.listOptions();

      expect(options.locations.map((o) => o.id), ['l1']);
      expect(options.batches.map((o) => o.id), ['b1']);
    },
  );

  test(
    'a real server error is surfaced, never hidden behind the fallback',
    () async {
      server.pages['/v1/locations'] = {null: 500};
      server.pages['/v1/batches'] = {null: _page([])};

      await expectLater(datasource.listOptions(), throwsA(isA<ApiException>()));
      expect(server.queries.containsKey('/v1/stock-levels'), isFalse);
    },
  );
}
