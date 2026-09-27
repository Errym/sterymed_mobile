// All 6 brief-required filter dimensions (page 10: patient, practitioner,
// laboratory, type of work, status, date period) are now wired end to end:
// `ProstheticCaseListFilters` carries all 6 (plus a free-text
// `practitionerId` — no "list practitioners" endpoint exists yet to back
// a real dropdown, see the filter sheet's own TODO), and `_fetch()` passes
// every one of them through to `ProstheticRepository.list()`, which
// already accepted them all along.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/bloc/prosthetic_case_list_bloc.dart';

import '../fixtures/prosthetic_case_fixture.dart';

class MockProstheticRepository extends Mock implements ProstheticRepository {}

void main() {
  late MockProstheticRepository repo;

  setUp(() {
    repo = MockProstheticRepository();
  });

  group('ProstheticCaseListBloc', () {
    blocTest<ProstheticCaseListBloc, ProstheticCaseListState>(
      'loads cases on LoadProstheticCases',
      build: () => ProstheticCaseListBloc(repo),
      setUp: () {
        when(() => repo.list(
              patientReference: any(named: 'patientReference'),
              practitionerId: any(named: 'practitionerId'),
              laboratoryId: any(named: 'laboratoryId'),
              workType: any(named: 'workType'),
              status: any(named: 'status'),
              from: any(named: 'from'),
              to: any(named: 'to'),
            )).thenAnswer(
          (_) async => CursorPage(items: [buildProstheticCase()]),
        );
      },
      act: (b) => b.add(const LoadProstheticCases()),
      expect: () => [
        isA<ProstheticCaseListState>().having(
          (s) => s.status,
          'status',
          ProstheticCaseListStatus.loading,
        ),
        isA<ProstheticCaseListState>()
            .having(
              (s) => s.status,
              'status',
              ProstheticCaseListStatus.success,
            )
            .having((s) => s.cases.length, 'cases', 1)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<ProstheticCaseListBloc, ProstheticCaseListState>(
      'emits failure with the server message on error',
      build: () => ProstheticCaseListBloc(repo),
      setUp: () {
        when(() => repo.list(
              patientReference: any(named: 'patientReference'),
              practitionerId: any(named: 'practitionerId'),
              laboratoryId: any(named: 'laboratoryId'),
              workType: any(named: 'workType'),
              status: any(named: 'status'),
              from: any(named: 'from'),
              to: any(named: 'to'),
            )).thenThrow(
          const ApiException(code: 'server_error', message: 'Erreur serveur.'),
        );
      },
      act: (b) => b.add(const LoadProstheticCases()),
      expect: () => [
        isA<ProstheticCaseListState>().having(
          (s) => s.status,
          'status',
          ProstheticCaseListStatus.loading,
        ),
        isA<ProstheticCaseListState>()
            .having(
              (s) => s.status,
              'status',
              ProstheticCaseListStatus.failure,
            )
            .having((s) => s.error, 'error', 'Erreur serveur.'),
      ],
    );

    blocTest<ProstheticCaseListBloc, ProstheticCaseListState>(
      'FilterProstheticCases passes the real filter fields through to the '
      'repository and replaces the active filters',
      build: () => ProstheticCaseListBloc(repo),
      setUp: () {
        when(() => repo.list(
              patientReference: 'PAT-000001',
              practitionerId: any(named: 'practitionerId'),
              laboratoryId: any(named: 'laboratoryId'),
              workType: 'crown',
              status: 'placed',
              from: any(named: 'from'),
              to: any(named: 'to'),
            )).thenAnswer((_) async => const CursorPage(items: []));
      },
      act: (b) => b.add(const FilterProstheticCases(
        ProstheticCaseListFilters(
          patientReference: 'PAT-000001',
          workType: 'crown',
          status: 'placed',
        ),
      )),
      expect: () => [
        isA<ProstheticCaseListState>().having(
          (s) => s.status,
          'status',
          ProstheticCaseListStatus.loading,
        ),
        isA<ProstheticCaseListState>()
            .having((s) => s.status, 'status', ProstheticCaseListStatus.success)
            .having(
              (s) => s.filters.patientReference,
              'filters.patientReference',
              'PAT-000001',
            ),
      ],
      verify: (_) {
        verify(() => repo.list(
              patientReference: 'PAT-000001',
              practitionerId: any(named: 'practitionerId'),
              laboratoryId: any(named: 'laboratoryId'),
              workType: 'crown',
              status: 'placed',
              from: any(named: 'from'),
              to: any(named: 'to'),
            )).called(1);
      },
    );

    blocTest<ProstheticCaseListBloc, ProstheticCaseListState>(
      'loads the next page and appends it on LoadMoreProstheticCases',
      build: () => ProstheticCaseListBloc(repo),
      seed: () => ProstheticCaseListState(
        status: ProstheticCaseListStatus.success,
        cases: [buildProstheticCase(id: 'case-1')],
        nextCursor: 'cursor-1',
      ),
      setUp: () {
        when(() => repo.loadMore('cursor-1')).thenAnswer(
          (_) async => CursorPage(items: [buildProstheticCase(id: 'case-2')]),
        );
      },
      act: (b) => b.add(const LoadMoreProstheticCases()),
      expect: () => [
        isA<ProstheticCaseListState>()
            .having((s) => s.isLoadingMore, 'isLoadingMore', true),
        isA<ProstheticCaseListState>()
            .having((s) => s.cases.length, 'cases', 2)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.isLoadingMore, 'isLoadingMore', false),
      ],
      verify: (_) {
        verify(() => repo.loadMore('cursor-1')).called(1);
      },
    );

    blocTest<ProstheticCaseListBloc, ProstheticCaseListState>(
      'LoadMoreProstheticCases is a no-op when there is no next cursor',
      build: () => ProstheticCaseListBloc(repo),
      seed: () => ProstheticCaseListState(
        status: ProstheticCaseListStatus.success,
        cases: [buildProstheticCase()],
      ),
      act: (b) => b.add(const LoadMoreProstheticCases()),
      expect: () => <ProstheticCaseListState>[],
      verify: (_) {
        verifyNever(() => repo.loadMore(any()));
      },
    );

    blocTest<ProstheticCaseListBloc, ProstheticCaseListState>(
      'LoadMoreProstheticCases is a no-op while already loading more',
      build: () => ProstheticCaseListBloc(repo),
      seed: () => ProstheticCaseListState(
        status: ProstheticCaseListStatus.success,
        cases: [buildProstheticCase()],
        nextCursor: 'cursor-1',
        isLoadingMore: true,
      ),
      act: (b) => b.add(const LoadMoreProstheticCases()),
      expect: () => <ProstheticCaseListState>[],
      verify: (_) {
        verifyNever(() => repo.loadMore(any()));
      },
    );

    blocTest<ProstheticCaseListBloc, ProstheticCaseListState>(
      'all 6 filter dimensions combine and are all sent to the repository '
      'together, dates formatted as YYYY-MM-DD',
      build: () => ProstheticCaseListBloc(repo),
      setUp: () {
        when(() => repo.list(
              patientReference: 'PAT-000001',
              practitionerId: 'prat-1',
              laboratoryId: 'lab-1',
              workType: 'crown',
              status: 'placed',
              from: '2026-01-01',
              to: '2026-01-31',
            )).thenAnswer((_) async => const CursorPage(items: []));
      },
      act: (b) => b.add(FilterProstheticCases(
        ProstheticCaseListFilters(
          patientReference: 'PAT-000001',
          practitionerId: 'prat-1',
          laboratoryId: 'lab-1',
          workType: 'crown',
          status: 'placed',
          from: DateTime(2026, 1, 1),
          to: DateTime(2026, 1, 31),
        ),
      )),
      expect: () => [
        isA<ProstheticCaseListState>().having(
          (s) => s.status,
          'status',
          ProstheticCaseListStatus.loading,
        ),
        isA<ProstheticCaseListState>().having(
          (s) => s.status,
          'status',
          ProstheticCaseListStatus.success,
        ),
      ],
      verify: (_) {
        verify(() => repo.list(
              patientReference: 'PAT-000001',
              practitionerId: 'prat-1',
              laboratoryId: 'lab-1',
              workType: 'crown',
              status: 'placed',
              from: '2026-01-01',
              to: '2026-01-31',
            )).called(1);
      },
    );

    blocTest<ProstheticCaseListBloc, ProstheticCaseListState>(
      'combined filters persist across a reload (simulates leaving the '
      'detail screen and coming back, which re-triggers LoadProstheticCases '
      'on the same bloc instance rather than a fresh one)',
      build: () => ProstheticCaseListBloc(repo),
      seed: () => const ProstheticCaseListState(
        status: ProstheticCaseListStatus.success,
        filters: ProstheticCaseListFilters(
          patientReference: 'PAT-000001',
          laboratoryId: 'lab-1',
          status: 'placed',
        ),
      ),
      setUp: () {
        when(() => repo.list(
              patientReference: 'PAT-000001',
              practitionerId: any(named: 'practitionerId'),
              laboratoryId: 'lab-1',
              workType: any(named: 'workType'),
              status: 'placed',
              from: any(named: 'from'),
              to: any(named: 'to'),
            )).thenAnswer(
          (_) async => CursorPage(items: [buildProstheticCase()]),
        );
      },
      act: (b) => b.add(const LoadProstheticCases()),
      expect: () => [
        isA<ProstheticCaseListState>()
            .having((s) => s.status, 'status', ProstheticCaseListStatus.loading)
            .having(
              (s) => s.filters.patientReference,
              'filters unchanged during reload',
              'PAT-000001',
            ),
        isA<ProstheticCaseListState>()
            .having((s) => s.status, 'status', ProstheticCaseListStatus.success)
            .having(
              (s) => s.filters,
              'filters still applied after reload',
              const ProstheticCaseListFilters(
                patientReference: 'PAT-000001',
                laboratoryId: 'lab-1',
                status: 'placed',
              ),
            ),
      ],
      verify: (_) {
        // The reload used the *seeded* (pre-navigation) filters, not empty
        // ones — proving LoadProstheticCases never resets state.filters.
        verify(() => repo.list(
              patientReference: 'PAT-000001',
              practitionerId: any(named: 'practitionerId'),
              laboratoryId: 'lab-1',
              workType: any(named: 'workType'),
              status: 'placed',
              from: any(named: 'from'),
              to: any(named: 'to'),
            )).called(1);
      },
    );
  });

  group('ProstheticCaseListFilters', () {
    test('copyWith clearX flags null out a single field, others untouched', () {
      const filters = ProstheticCaseListFilters(
        patientReference: 'PAT-000001',
        practitionerId: 'prat-1',
        laboratoryId: 'lab-1',
        workType: 'crown',
        status: 'placed',
        from: null,
        to: null,
      );

      final cleared = filters.copyWith(clearLaboratoryId: true);

      expect(cleared.laboratoryId, isNull);
      expect(cleared.patientReference, 'PAT-000001');
      expect(cleared.practitionerId, 'prat-1');
      expect(cleared.workType, 'crown');
      expect(cleared.status, 'placed');
    });

    test('isEmpty is true only when all 7 fields are null', () {
      expect(const ProstheticCaseListFilters().isEmpty, isTrue);
      expect(
        const ProstheticCaseListFilters(status: 'placed').isEmpty,
        isFalse,
      );
      expect(
        ProstheticCaseListFilters(from: DateTime(2026, 1, 1)).isEmpty,
        isFalse,
      );
    });
  });
}
