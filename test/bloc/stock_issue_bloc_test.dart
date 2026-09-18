import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/stock/data/models/stock_movement_data.dart';
import 'package:steriymed_mobile/features/stock/data/repositories/stock_repository.dart';
import 'package:steriymed_mobile/features/stock/presentation/bloc/stock_issue_bloc.dart';

class MockStockRepository extends Mock implements StockRepository {}

void main() {
  late MockStockRepository repo;

  setUp(() {
    repo = MockStockRepository();
  });

  group('StockIssueBloc', () {
    blocTest<StockIssueBloc, StockIssueState>(
      'emits [loading, success] on submit',
      build: () => StockIssueBloc(repo),
      setUp: () {
        when(() => repo.issue(
              batchId: any(named: 'batchId'),
              locationId: any(named: 'locationId'),
              qty: any(named: 'qty'),
              reason: any(named: 'reason'),
            )).thenAnswer((_) async => StockMovementData(
              id: 'm-1',
              kind: 'issue',
              batchId: 'b-1',
              locationId: 'l-1',
              qty: 2,
              createdAt: DateTime.now(),
            ));
      },
      act: (b) => b.add(const SubmitStockIssue(
        batchId: 'b-1',
        locationId: 'l-1',
        qty: 2,
      )),
      expect: () => [
        isA<StockIssueState>()
            .having((s) => s.status, 'status', StockIssueStatus.loading),
        isA<StockIssueState>()
            .having((s) => s.status, 'status', StockIssueStatus.success),
      ],
    );

    blocTest<StockIssueBloc, StockIssueState>(
      'emits [loading, failure] on 422',
      build: () => StockIssueBloc(repo),
      setUp: () {
        when(() => repo.issue(
              batchId: any(named: 'batchId'),
              locationId: any(named: 'locationId'),
              qty: any(named: 'qty'),
              reason: any(named: 'reason'),
            )).thenThrow(const ApiException(
          code: 'validation_error',
          message: 'Quantité invalide.',
          statusCode: 422,
        ));
      },
      act: (b) => b.add(const SubmitStockIssue(
        batchId: 'b-1',
        locationId: 'l-1',
        qty: 0,
      )),
      expect: () => [
        isA<StockIssueState>()
            .having((s) => s.status, 'status', StockIssueStatus.loading),
        isA<StockIssueState>()
            .having((s) => s.status, 'status', StockIssueStatus.failure)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );
  });
}
