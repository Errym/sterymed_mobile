import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/cycles/presentation/bloc/cycle_detail_bloc.dart';

import '../fixtures/cycle_fixture.dart';

class MockCycleRepository extends Mock implements CycleRepository {}

void main() {
  late MockCycleRepository repo;

  setUp(() {
    repo = MockCycleRepository();
  });

  group('CycleDetailBloc', () {
    blocTest<CycleDetailBloc, CycleDetailState>(
      'loads cycle + items + tests + attachments',
      build: () => CycleDetailBloc(repo),
      setUp: () {
        when(() => repo.show(any()))
            .thenAnswer((_) async => buildCycle());
        when(() => repo.listItems(any()))
            .thenAnswer((_) async => [buildCycleItem()]);
        when(() => repo.listControlTests(any()))
            .thenAnswer((_) async => [buildControlTest()]);
        when(() => repo.listAttachments(any()))
            .thenAnswer((_) async => []);
      },
      act: (bloc) => bloc.add(const LoadCycleDetail('cycle-1')),
      expect: () => [
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.loading),
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.success)
            .having((s) => s.cycle, 'cycle', isNotNull)
            .having((s) => s.items.length, 'items', 1)
            .having((s) => s.controlTests.length, 'tests', 1),
      ],
    );

    blocTest<CycleDetailBloc, CycleDetailState>(
      'cycle load failure -> failure state',
      build: () => CycleDetailBloc(repo),
      setUp: () {
        when(() => repo.show(any()))
            .thenThrow(const ApiException(code: 'server_error', message: 'Erreur'));
      },
      act: (bloc) => bloc.add(const LoadCycleDetail('cycle-1')),
      expect: () => [
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.loading),
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.failure),
      ],
    );

    blocTest<CycleDetailBloc, CycleDetailState>(
      'cycle loads but items fail -> still success, aux error set',
      build: () => CycleDetailBloc(repo),
      setUp: () {
        when(() => repo.show(any())).thenAnswer((_) async => buildCycle());
        when(() => repo.listItems(any()))
            .thenThrow(const ApiException(code: 'server_error', message: 'X'));
        when(() => repo.listControlTests(any()))
            .thenAnswer((_) async => []);
        when(() => repo.listAttachments(any()))
            .thenAnswer((_) async => []);
      },
      act: (bloc) => bloc.add(const LoadCycleDetail('cycle-1')),
      expect: () => [
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.loading),
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.success),
        isA<CycleDetailState>()
            .having((s) => s.status, 'status', CycleDetailStatus.success)
            .having((s) => s.cycle, 'cycle', isNotNull)
            .having((s) => s.error, 'error', isNotNull),
      ],
    );
  });
}
