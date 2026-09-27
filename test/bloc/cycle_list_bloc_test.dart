import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/cycles/presentation/bloc/cycle_list_bloc.dart';

import '../fixtures/cycle_fixture.dart';

class MockCycleRepository extends Mock implements CycleRepository {}

void main() {
  late MockCycleRepository repo;

  setUp(() {
    repo = MockCycleRepository();
  });

  group('CycleListBloc', () {
    blocTest<CycleListBloc, CycleListState>(
      'loads cycles on LoadCycles',
      build: () => CycleListBloc(repo),
      setUp: () {
        when(() => repo.list(forceRefresh: true)).thenAnswer(
          (_) async => CursorPage(items: [buildCycle()]),
        );
      },
      act: (b) => b.add(const LoadCycles()),
      expect: () => [
        isA<CycleListState>()
            .having((s) => s.status, 'status', CycleListStatus.loading),
        isA<CycleListState>()
            .having((s) => s.status, 'status', CycleListStatus.success)
            .having((s) => s.cycles.length, 'cycles', 1)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<CycleListBloc, CycleListState>(
      'emits failure with the server message on error',
      build: () => CycleListBloc(repo),
      setUp: () {
        when(() => repo.list(forceRefresh: true)).thenThrow(
          const ApiException(code: 'server_error', message: 'Erreur serveur.'),
        );
      },
      act: (b) => b.add(const LoadCycles()),
      expect: () => [
        isA<CycleListState>()
            .having((s) => s.status, 'status', CycleListStatus.loading),
        isA<CycleListState>()
            .having((s) => s.status, 'status', CycleListStatus.failure)
            .having((s) => s.error, 'error', 'Erreur serveur.'),
      ],
    );

    blocTest<CycleListBloc, CycleListState>(
      'RefreshCycles reloads without an intermediate loading state',
      build: () => CycleListBloc(repo),
      seed: () => CycleListState(
        status: CycleListStatus.success,
        cycles: [buildCycle(id: 'old')],
      ),
      setUp: () {
        when(() => repo.list(forceRefresh: true)).thenAnswer(
          (_) async => CursorPage(items: [buildCycle(id: 'new')]),
        );
      },
      act: (b) => b.add(const RefreshCycles()),
      expect: () => [
        isA<CycleListState>()
            .having((s) => s.cycles.map((c) => c.id), 'cycles', ['new']),
      ],
    );

    blocTest<CycleListBloc, CycleListState>(
      'loads the next page and appends it on LoadMoreCycles',
      build: () => CycleListBloc(repo),
      seed: () => CycleListState(
        status: CycleListStatus.success,
        cycles: [buildCycle(id: 'cycle-1')],
        nextCursor: 'cursor-1',
      ),
      setUp: () {
        when(() => repo.loadMore('cursor-1')).thenAnswer(
          (_) async => CursorPage(items: [buildCycle(id: 'cycle-2')]),
        );
      },
      act: (b) => b.add(const LoadMoreCycles()),
      expect: () => [
        isA<CycleListState>()
            .having((s) => s.isLoadingMore, 'isLoadingMore', true),
        isA<CycleListState>()
            .having((s) => s.cycles.length, 'cycles', 2)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.isLoadingMore, 'isLoadingMore', false),
      ],
      verify: (_) {
        verify(() => repo.loadMore('cursor-1')).called(1);
      },
    );

    blocTest<CycleListBloc, CycleListState>(
      'LoadMoreCycles is a no-op when there is no next cursor',
      build: () => CycleListBloc(repo),
      seed: () => CycleListState(
        status: CycleListStatus.success,
        cycles: [buildCycle()],
      ),
      act: (b) => b.add(const LoadMoreCycles()),
      expect: () => <CycleListState>[],
      verify: (_) {
        verifyNever(() => repo.loadMore(any()));
      },
    );

    blocTest<CycleListBloc, CycleListState>(
      'FilterCycles(null) explicitly clears the status filter',
      build: () => CycleListBloc(repo),
      seed: () => const CycleListState(selectedStatus: 'completed'),
      act: (b) => b.add(const FilterCycles(null)),
      expect: () => [
        isA<CycleListState>()
            .having((s) => s.selectedStatus, 'selectedStatus', isNull),
      ],
    );

    blocTest<CycleListBloc, CycleListState>(
      'FilterCycles(status) sets the status filter',
      build: () => CycleListBloc(repo),
      act: (b) => b.add(const FilterCycles('running')),
      expect: () => [
        isA<CycleListState>()
            .having((s) => s.selectedStatus, 'selectedStatus', 'running'),
      ],
    );

    blocTest<CycleListBloc, CycleListState>(
      'SearchCycles sets the search query',
      build: () => CycleListBloc(repo),
      act: (b) => b.add(const SearchCycles('CT-001')),
      expect: () => [
        isA<CycleListState>()
            .having((s) => s.searchQuery, 'searchQuery', 'CT-001'),
      ],
    );

    test(
      'state.filtered combines status filter and search query, matching '
      'on number, device, program, or operator',
      () {
        final state = CycleListState(
          cycles: [
            buildCycle(id: 'a', number: 'CT-001', status: 'completed'),
            buildCycle(id: 'b', number: 'CT-002', status: 'running'),
            buildCycle(id: 'c', number: 'CT-003', status: 'completed'),
          ],
          selectedStatus: 'completed',
          searchQuery: 'ct-001',
        );
        expect(state.filtered.map((c) => c.id), ['a']);
      },
    );
  });
}
