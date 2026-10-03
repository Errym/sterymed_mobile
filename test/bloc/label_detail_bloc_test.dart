import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_usage_repository.dart';
import 'package:steriymed_mobile/features/labels/presentation/bloc/label_detail_bloc.dart';

import '../fixtures/label_fixture.dart';

class MockLabelRepository extends Mock implements LabelRepository {}

class MockLabelUsageRepository extends Mock implements LabelUsageRepository {}

void main() {
  late MockLabelRepository repo;
  late MockLabelUsageRepository usageRepo;

  setUp(() {
    repo = MockLabelRepository();
    usageRepo = MockLabelUsageRepository();
  });

  group('LabelDetailBloc', () {
    blocTest<LabelDetailBloc, LabelDetailState>(
      'loads the label then its usage history',
      build: () => LabelDetailBloc(repo, usageRepo),
      setUp: () {
        when(() => repo.getByCode('LOT-42'))
            .thenAnswer((_) async => buildLabelScanResult());
        when(() => usageRepo.history('label-1'))
            .thenAnswer((_) async => [buildLabelUsage()]);
      },
      act: (b) => b.add(const LoadLabel('LOT-42')),
      expect: () => [
        isA<LabelDetailState>()
            .having((s) => s.status, 'status', LabelDetailStatus.loading),
        isA<LabelDetailState>()
            .having((s) => s.status, 'status', LabelDetailStatus.success)
            .having((s) => s.result?.labelId, 'result.labelId', 'label-1'),
        isA<LabelDetailState>()
            .having((s) => s.historyLoading, 'historyLoading', true),
        isA<LabelDetailState>()
            .having((s) => s.historyLoading, 'historyLoading', false)
            .having((s) => s.history.length, 'history', 1),
      ],
    );

    blocTest<LabelDetailBloc, LabelDetailState>(
      'a lookup failure surfaces the server message and error code, and '
      'never touches usage history',
      build: () => LabelDetailBloc(repo, usageRepo),
      setUp: () {
        when(() => repo.getByCode('UNKNOWN')).thenThrow(const ApiException(
          code: 'not_found',
          message: 'Étiquette introuvable.',
        ));
      },
      act: (b) => b.add(const LoadLabel('UNKNOWN')),
      expect: () => [
        isA<LabelDetailState>()
            .having((s) => s.status, 'status', LabelDetailStatus.loading),
        isA<LabelDetailState>()
            .having((s) => s.status, 'status', LabelDetailStatus.failure)
            .having((s) => s.error, 'error', 'Étiquette introuvable.')
            .having((s) => s.errorCode, 'errorCode', 'not_found'),
      ],
      verify: (_) {
        verifyNever(() => usageRepo.history(any()));
      },
    );

    blocTest<LabelDetailBloc, LabelDetailState>(
      'a non-API failure (e.g. a malformed payload) still ends loading in a '
      'failure state instead of spinning forever',
      build: () => LabelDetailBloc(repo, usageRepo),
      setUp: () {
        when(() => repo.getByCode('LOT-42')).thenThrow(const FormatException());
      },
      act: (b) => b.add(const LoadLabel('LOT-42')),
      expect: () => [
        isA<LabelDetailState>()
            .having((s) => s.status, 'status', LabelDetailStatus.loading),
        isA<LabelDetailState>()
            .having((s) => s.status, 'status', LabelDetailStatus.failure)
            .having((s) => s.error, 'error', isNotEmpty),
      ],
    );

    blocTest<LabelDetailBloc, LabelDetailState>(
      'a failed history fetch is swallowed — the label still shows',
      build: () => LabelDetailBloc(repo, usageRepo),
      setUp: () {
        when(() => repo.getByCode('LOT-42'))
            .thenAnswer((_) async => buildLabelScanResult());
        when(() => usageRepo.history('label-1'))
            .thenThrow(Exception('network hiccup'));
      },
      act: (b) => b.add(const LoadLabel('LOT-42')),
      expect: () => [
        isA<LabelDetailState>()
            .having((s) => s.status, 'status', LabelDetailStatus.loading),
        isA<LabelDetailState>()
            .having((s) => s.status, 'status', LabelDetailStatus.success),
        isA<LabelDetailState>()
            .having((s) => s.historyLoading, 'historyLoading', true),
        isA<LabelDetailState>()
            .having((s) => s.historyLoading, 'historyLoading', false)
            .having((s) => s.history, 'history', isEmpty)
            .having(
              (s) => s.status,
              'status stays success',
              LabelDetailStatus.success,
            ),
      ],
    );

    blocTest<LabelDetailBloc, LabelDetailState>(
      'without a usage repository, history is never fetched',
      build: () => LabelDetailBloc(repo),
      setUp: () {
        when(() => repo.getByCode('LOT-42'))
            .thenAnswer((_) async => buildLabelScanResult());
      },
      act: (b) => b.add(const LoadLabel('LOT-42')),
      expect: () => [
        isA<LabelDetailState>()
            .having((s) => s.status, 'status', LabelDetailStatus.loading),
        isA<LabelDetailState>()
            .having((s) => s.status, 'status', LabelDetailStatus.success),
      ],
      verify: (_) {
        verifyNever(() => usageRepo.history(any()));
      },
    );
  });
}
