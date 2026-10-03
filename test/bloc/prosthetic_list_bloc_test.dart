// T6.2 (brief §10): the six filters plus the dashboard scope live in the bloc
// state; they survive paging and refresh, travel WITH the cursor (a cursor
// only marks where a page ended), and a late answer for an old filter set can
// never overwrite the list of a newer one.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_case_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/models/prosthetic_summary_data.dart';
import 'package:steriymed_mobile/features/prosthetic/data/repositories/prosthetic_repository.dart';
import 'package:steriymed_mobile/features/prosthetic/presentation/bloc/prosthetic_case_list_bloc.dart';

import '../fixtures/prosthetic_case_fixture.dart';

class MockProstheticRepository extends Mock implements ProstheticRepository {}

void main() {
  late MockProstheticRepository repo;

  setUp(() {
    repo = MockProstheticRepository();
  });

  Future<CursorPage<ProstheticCaseData>> Function(Invocation) page(
    List<ProstheticCaseData> items, {
    String? next,
  }) =>
      (_) async => CursorPage(items: items, nextCursor: next);

  void stubList({
    String? cursor,
    String? scope,
    String? status,
    required Future<CursorPage<ProstheticCaseData>> Function(Invocation) answer,
  }) {
    when(() => repo.list(
          cursor: cursor,
          patientReference: any(named: 'patientReference'),
          practitionerId: any(named: 'practitionerId'),
          laboratoryId: any(named: 'laboratoryId'),
          workType: any(named: 'workType'),
          status: status,
          from: any(named: 'from'),
          to: any(named: 'to'),
          scope: scope,
        )).thenAnswer(answer);
  }

  void stubSummary(int total, {String? scope, String? status}) {
    when(() => repo.summary(
          patientReference: any(named: 'patientReference'),
          practitionerId: any(named: 'practitionerId'),
          laboratoryId: any(named: 'laboratoryId'),
          workType: any(named: 'workType'),
          status: status,
          from: any(named: 'from'),
          to: any(named: 'to'),
          scope: scope,
        )).thenAnswer((_) async => ProstheticSummaryData(total: total));
  }

  test('loads the first page and the exact total', () async {
    stubList(answer: page([buildProstheticCase()]));
    stubSummary(42);
    final bloc = ProstheticCaseListBloc(repo)..add(const LoadProstheticCases());
    await bloc.stream.firstWhere((s) => s.status == ProstheticCaseListStatus.success);

    expect(bloc.state.cases.length, 1);
    expect(bloc.state.total, 42, reason: 'the whole result, not the page');
    expect(bloc.state.hasMore, isFalse);
    await bloc.close();
  });

  test('the list still shows when only the total request fails', () async {
    stubList(answer: page([buildProstheticCase()]));
    when(() => repo.summary(
          patientReference: any(named: 'patientReference'),
          practitionerId: any(named: 'practitionerId'),
          laboratoryId: any(named: 'laboratoryId'),
          workType: any(named: 'workType'),
          status: any(named: 'status'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          scope: any(named: 'scope'),
        )).thenThrow(const ApiException(code: 'x', message: 'boom'));
    final bloc = ProstheticCaseListBloc(repo)..add(const LoadProstheticCases());
    await bloc.stream.firstWhere((s) => s.status == ProstheticCaseListStatus.success);

    expect(bloc.state.cases.length, 1);
    expect(bloc.state.total, isNull);
    await bloc.close();
  });

  test('a failed load reports the error and keeps the chosen filters', () async {
    stubList(
      status: 'placed',
      answer: (_) async => throw const ApiException(code: 'x', message: 'Hors ligne'),
    );
    stubSummary(0, status: 'placed');
    final bloc = ProstheticCaseListBloc(repo)
      ..add(const FilterProstheticCases(ProstheticCaseListFilters(status: 'placed')));
    await bloc.stream.firstWhere((s) => s.status == ProstheticCaseListStatus.failure);

    expect(bloc.state.error, 'Hors ligne');
    expect(bloc.state.filters.status, 'placed',
        reason: 'retry and refresh must reuse what the user chose');
    await bloc.close();
  });

  test('all six filters plus the scope reach the repository, dates as YYYY-MM-DD',
      () async {
    when(() => repo.list(
          cursor: null,
          patientReference: 'PAT-000001',
          practitionerId: 'prat-1',
          laboratoryId: 'lab-1',
          workType: 'crown',
          status: 'placed',
          from: '2026-01-01',
          to: '2026-01-31',
          scope: 'payments_due',
        )).thenAnswer((_) async => const CursorPage(items: []));
    when(() => repo.summary(
          patientReference: 'PAT-000001',
          practitionerId: 'prat-1',
          laboratoryId: 'lab-1',
          workType: 'crown',
          status: 'placed',
          from: '2026-01-01',
          to: '2026-01-31',
          scope: 'payments_due',
        )).thenAnswer((_) async => const ProstheticSummaryData(total: 0));

    final bloc = ProstheticCaseListBloc(repo)
      ..add(FilterProstheticCases(ProstheticCaseListFilters(
        patientReference: 'PAT-000001',
        practitionerId: 'prat-1',
        laboratoryId: 'lab-1',
        workType: 'crown',
        status: 'placed',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
        scope: 'payments_due',
      )));
    await bloc.stream.firstWhere((s) => s.status == ProstheticCaseListStatus.success);
    await bloc.close();
    // The stubs above only match when every value arrived: reaching success
    // without a MissingStubError proves all seven did.
  });

  test('page 2 carries the SAME filters as page 1 (the cursor does not)', () async {
    stubList(
      scope: 'at_laboratory',
      answer: page([buildProstheticCase(id: 'case-1')], next: 'cursor-1'),
    );
    stubSummary(2, scope: 'at_laboratory');
    stubList(
      cursor: 'cursor-1',
      scope: 'at_laboratory',
      answer: page([buildProstheticCase(id: 'case-2')]),
    );

    final bloc = ProstheticCaseListBloc(repo)
      ..add(const FilterProstheticCases(ProstheticCaseListFilters(scope: 'at_laboratory')));
    await bloc.stream.firstWhere((s) => s.status == ProstheticCaseListStatus.success);
    bloc.add(const LoadMoreProstheticCases());
    await bloc.stream.firstWhere((s) => s.cases.length == 2);

    expect(bloc.state.cases.map((c) => c.id), ['case-1', 'case-2']);
    expect(bloc.state.hasMore, isFalse);
    expect(bloc.state.filters.scope, 'at_laboratory');
    verify(() => repo.list(
          cursor: 'cursor-1',
          patientReference: any(named: 'patientReference'),
          practitionerId: any(named: 'practitionerId'),
          laboratoryId: any(named: 'laboratoryId'),
          workType: any(named: 'workType'),
          status: any(named: 'status'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          scope: 'at_laboratory',
        )).called(1);
    await bloc.close();
  });

  test('refresh (LoadProstheticCases) re-reads with the filters already chosen',
      () async {
    stubList(status: 'placed', answer: page([buildProstheticCase()]));
    stubSummary(1, status: 'placed');
    final bloc = ProstheticCaseListBloc(repo)
      ..add(const FilterProstheticCases(ProstheticCaseListFilters(status: 'placed')));
    await bloc.stream.firstWhere((s) => s.status == ProstheticCaseListStatus.success);

    bloc.add(const LoadProstheticCases());
    await bloc.stream.firstWhere((s) => s.status == ProstheticCaseListStatus.success);

    expect(bloc.state.filters.status, 'placed');
    verify(() => repo.list(
          cursor: null,
          patientReference: any(named: 'patientReference'),
          practitionerId: any(named: 'practitionerId'),
          laboratoryId: any(named: 'laboratoryId'),
          workType: any(named: 'workType'),
          status: 'placed',
          from: any(named: 'from'),
          to: any(named: 'to'),
          scope: any(named: 'scope'),
        )).called(2);
    await bloc.close();
  });

  test('a late answer for an OLD filter set never overwrites the newer list',
      () async {
    final slow = Completer<CursorPage<ProstheticCaseData>>();
    stubList(status: 'sent_to_laboratory', answer: (_) => slow.future);
    stubSummary(99, status: 'sent_to_laboratory');
    stubList(status: 'placed', answer: page([buildProstheticCase(id: 'new')]));
    stubSummary(1, status: 'placed');

    final bloc = ProstheticCaseListBloc(repo)
      ..add(const FilterProstheticCases(
          ProstheticCaseListFilters(status: 'sent_to_laboratory')));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const FilterProstheticCases(ProstheticCaseListFilters(status: 'placed')));
    await bloc.stream.firstWhere((s) => s.status == ProstheticCaseListStatus.success);

    // The slow, OLD answer now arrives.
    slow.complete(CursorPage(items: [buildProstheticCase(id: 'old')]));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(bloc.state.cases.map((c) => c.id), ['new']);
    expect(bloc.state.filters.status, 'placed');
    expect(bloc.state.total, 1);
    await bloc.close();
  });

  test('LoadMore is a no-op without a next cursor and while already loading more',
      () async {
    final bloc = ProstheticCaseListBloc(repo);
    bloc.emit(ProstheticCaseListState(
      status: ProstheticCaseListStatus.success,
      cases: [buildProstheticCase()],
    ));
    bloc.add(const LoadMoreProstheticCases());
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => repo.list(
          cursor: any(named: 'cursor'),
          patientReference: any(named: 'patientReference'),
          practitionerId: any(named: 'practitionerId'),
          laboratoryId: any(named: 'laboratoryId'),
          workType: any(named: 'workType'),
          status: any(named: 'status'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          scope: any(named: 'scope'),
        ));
    await bloc.close();
  });

  test('filters equality, isEmpty and clear flags', () {
    const empty = ProstheticCaseListFilters();
    expect(empty.isEmpty, isTrue);
    const scoped = ProstheticCaseListFilters(scope: 'active');
    expect(scoped.isEmpty, isFalse);
    expect(scoped.copyWith(clearScope: true), empty);
    expect(scoped, const ProstheticCaseListFilters(scope: 'active'));
  });
}
