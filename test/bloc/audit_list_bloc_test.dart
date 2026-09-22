import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/features/history/data/repositories/audit_repository.dart';
import 'package:steriymed_mobile/features/history/presentation/bloc/audit_list_bloc.dart';

import '../fixtures/audit_event_fixture.dart';

class MockAuditRepository extends Mock implements AuditRepository {}

void main() {
  late MockAuditRepository repo;

  setUp(() {
    repo = MockAuditRepository();
  });

  group('AuditListBloc', () {
    blocTest<AuditListBloc, AuditListState>(
      'loads events',
      build: () => AuditListBloc(repo),
      setUp: () {
        when(() => repo.list(
              cursor: any(named: 'cursor'),
              action: any(named: 'action'),
              forceRefresh: any(named: 'forceRefresh'),
            )).thenAnswer((_) async => CursorPage(items: [buildAuditEvent()]));
      },
      act: (b) => b.add(const LoadAuditEvents()),
      expect: () => [
        isA<AuditListState>()
            .having((s) => s.status, 'status', AuditStatus.loading),
        isA<AuditListState>()
            .having((s) => s.status, 'status', AuditStatus.success)
            .having((s) => s.events.length, 'events', 1)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
    );

    blocTest<AuditListBloc, AuditListState>(
      'emits failure on error',
      build: () => AuditListBloc(repo),
      setUp: () {
        when(() => repo.list(
              cursor: any(named: 'cursor'),
              action: any(named: 'action'),
              forceRefresh: any(named: 'forceRefresh'),
            )).thenThrow(const ApiException(
          code: 'server_error',
          message: 'Erreur serveur.',
        ));
      },
      act: (b) => b.add(const LoadAuditEvents()),
      expect: () => [
        isA<AuditListState>()
            .having((s) => s.status, 'status', AuditStatus.loading),
        isA<AuditListState>()
            .having((s) => s.status, 'status', AuditStatus.failure),
      ],
    );

    blocTest<AuditListBloc, AuditListState>(
      'loads the next page and appends it on LoadMoreAuditEvents',
      build: () => AuditListBloc(repo),
      seed: () => AuditListState(
        status: AuditStatus.success,
        events: [buildAuditEvent(id: 'e1')],
        nextCursor: 'cursor-1',
      ),
      setUp: () {
        when(() => repo.list(cursor: 'cursor-1', action: any(named: 'action')))
            .thenAnswer((_) async => CursorPage(items: [buildAuditEvent(id: 'e2')]));
      },
      act: (b) => b.add(const LoadMoreAuditEvents()),
      expect: () => [
        isA<AuditListState>()
            .having((s) => s.isLoadingMore, 'isLoadingMore', true),
        isA<AuditListState>()
            .having((s) => s.events.length, 'events', 2)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.isLoadingMore, 'isLoadingMore', false),
      ],
    );

    blocTest<AuditListBloc, AuditListState>(
      'filtering reloads from the first page',
      build: () => AuditListBloc(repo),
      setUp: () {
        when(() => repo.list(
              cursor: any(named: 'cursor'),
              action: any(named: 'action'),
              forceRefresh: any(named: 'forceRefresh'),
            )).thenAnswer((_) async => const CursorPage(items: []));
      },
      act: (b) => b.add(const FilterAuditEvents('cycle.started')),
      verify: (_) {
        verify(() => repo.list(
              cursor: null,
              action: 'cycle.started',
              forceRefresh: false,
            )).called(1);
      },
    );
  });
}
