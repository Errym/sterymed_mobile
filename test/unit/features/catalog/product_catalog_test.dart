// Catalog behaviour the audit flagged: the list must be complete and never show
// a stale answer, edits must be able to CLEAR optional fields, and a failed
// delete must be visible.
import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/cache/cache.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/catalog/data/datasources/product_remote_datasource.dart';
import 'package:steriymed_mobile/features/catalog/data/models/product_data.dart';
import 'package:steriymed_mobile/features/catalog/data/repositories/product_repository.dart';
import 'package:steriymed_mobile/features/catalog/presentation/bloc/product_list_bloc.dart';

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
    final body = answer!(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _row(String id, {String? barcode}) => {
  'id': id,
  'name': 'Produit $id',
  'reference': 'REF-$id',
  'unit': 'box',
  'min_threshold': 2,
  'is_sterilizable': false,
  'barcode': barcode,
  'category_id': null,
  'default_location_id': null,
};

class _MockRepo extends Mock implements ProductRepository {}

void main() {
  group('ProductRemoteDatasource', () {
    late _Server server;
    late ProductRemoteDatasource datasource;

    setUp(() {
      server = _Server();
      datasource = ProductRemoteDatasource(
        Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))
          ..httpClientAdapter = server,
      );
    });

    test('lists every page, not just the first 100', () async {
      server.answer = (o) {
        final cursor = o.queryParameters['cursor'];
        if (cursor == null) {
          return {
            'data': [_row('1'), _row('2')],
            'meta': {'next_cursor': 'c2'},
          };
        }
        return {
          'data': [_row('3')],
          'meta': {'next_cursor': null},
        };
      };

      final products = await datasource.list();

      expect(products.map((p) => p.id), ['1', '2', '3']);
      expect(server.requests, hasLength(2));
      expect(server.requests.last.queryParameters['cursor'], 'c2');
    });

    test('passes the search term on every page', () async {
      server.answer = (o) => {
        'data': [_row('1')],
        'meta': {'next_cursor': null},
      };

      await datasource.list(search: '  gants ');

      expect(server.requests.single.queryParameters['search'], 'gants');
    });

    test(
      'update sends explicit nulls so cleared fields are really cleared',
      () async {
        server.answer = (_) => _row('1');
        const req = ProductCreateRequest(
          name: 'Gants',
          reference: 'G-1',
          unit: 'box',
          minThreshold: 3,
          isSterilizable: false,
          barcode: null, // the user emptied it
          categoryId: null, // chose "Aucune"
          defaultLocationId: null,
        );

        await datasource.update('1', req);

        final body = server.requests.single.data as Map;
        expect(body.containsKey('barcode'), isTrue);
        expect(body['barcode'], isNull);
        expect(body.containsKey('category_id'), isTrue);
        expect(body['category_id'], isNull);
        expect(body.containsKey('default_location_id'), isTrue);
        expect(body['default_location_id'], isNull);
      },
    );

    test('create still omits empty optional fields', () async {
      server.answer = (_) => _row('1');
      const req = ProductCreateRequest(
        name: 'Gants',
        reference: 'G-1',
        unit: 'box',
        minThreshold: 3,
        isSterilizable: false,
      );

      await datasource.create(req);

      final body = server.requests.single.data as Map;
      expect(body.containsKey('barcode'), isFalse);
      expect(body.containsKey('category_id'), isFalse);
    });
  });

  group('ProductListBloc', () {
    late _MockRepo repo;

    setUp(() => repo = _MockRepo());

    ProductData product(String id) => ProductData(
      id: id,
      name: 'P$id',
      reference: 'R$id',
      unit: 'u',
      minThreshold: 1,
      isSterilizable: false,
    );

    blocTest<ProductListBloc, ProductListState>(
      'a slow answer for an old query never overwrites the newer one',
      build: () {
        // Two searches in flight: the first answers last.
        when(
          () => repo.list(
            search: 'ga',
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return [product('old')];
        });
        when(
          () => repo.list(
            search: 'gants',
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => [product('new')]);
        return ProductListBloc(repo);
      },
      act: (bloc) async {
        bloc.add(const SearchProducts('ga'));
        await Future<void>.delayed(const Duration(milliseconds: 350));
        bloc.add(const SearchProducts('gants'));
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      verify: (bloc) {
        expect(bloc.state.products.map((p) => p.id), ['new']);
        expect(bloc.state.status, ProductListStatus.success);
      },
    );

    blocTest<ProductListBloc, ProductListState>(
      'a refresh keeps the search term and bypasses the cache',
      build: () {
        when(
          () => repo.list(
            search: any(named: 'search'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => [product('1')]);
        return ProductListBloc(repo);
      },
      seed: () => const ProductListState(query: 'gants'),
      act: (bloc) => bloc.add(const LoadProducts()),
      verify: (_) {
        verify(() => repo.list(search: 'gants', forceRefresh: true)).called(1);
      },
    );

    blocTest<ProductListBloc, ProductListState>(
      'a failed delete keeps the list and reports the reason',
      build: () {
        when(() => repo.destroy('1')).thenThrow(
          const ApiException(
            code: 'CONFLICT',
            message: 'Ce produit est utilisé par un lot.',
            statusCode: 409,
          ),
        );
        return ProductListBloc(repo);
      },
      seed: () => ProductListState(
        status: ProductListStatus.success,
        products: [product('1')],
      ),
      act: (bloc) => bloc.add(const DeleteProduct('1')),
      verify: (bloc) {
        expect(bloc.state.products, hasLength(1));
        expect(bloc.state.status, ProductListStatus.success);
        expect(bloc.state.actionError, 'Ce produit est utilisé par un lot.');
        expect(bloc.state.error, isNull);
      },
    );

    blocTest<ProductListBloc, ProductListState>(
      'the action error can be cleared once shown',
      build: () => ProductListBloc(repo),
      seed: () => const ProductListState(actionError: 'x'),
      act: (bloc) => bloc.add(const ClearProductActionError()),
      verify: (bloc) => expect(bloc.state.actionError, isNull),
    );
  });

  group('ProductRepository cache', () {
    test('forceRefresh bypasses a cached list', () async {
      final server = _Server()
        ..answer = (_) => {
          'data': [_row('1')],
          'meta': {'next_cursor': null},
        };
      final repo = ProductRepository(
        ProductRemoteDatasource(
          Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))
            ..httpClientAdapter = server,
        ),
        AppCache(),
      );

      await repo.list();
      await repo.list();
      expect(server.requests, hasLength(1));
      await repo.list(forceRefresh: true);
      expect(server.requests, hasLength(2));
    });
  });
}
