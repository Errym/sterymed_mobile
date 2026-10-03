// Phase 7 / T7.3: the audit journal filters by action, actor, subject and
// period, never fails silently, and a slow answer for an old filter cannot
// overwrite the current one.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/network/cursor_page.dart';
import 'package:steriymed_mobile/features/history/data/datasources/audit_remote_datasource.dart';
import 'package:steriymed_mobile/features/history/data/models/audit_event_data.dart';
import 'package:steriymed_mobile/features/history/data/repositories/audit_repository.dart';
import 'package:steriymed_mobile/features/history/presentation/bloc/audit_list_bloc.dart';
import 'package:steriymed_mobile/features/history/presentation/screens/audit_list_screen.dart';

import '../../fixtures/audit_event_fixture.dart';
import '../../helpers/pump_app.dart';

class _MockRepo extends Mock implements AuditRepository {}

class _MockDio extends Mock implements Dio {}

void _stubList(
  _MockRepo repo,
  Future<CursorPage<AuditEventData>> Function(Invocation) answer,
) {
  when(() => repo.list(
        cursor: any(named: 'cursor'),
        action: any(named: 'action'),
        actorId: any(named: 'actorId'),
        subjectType: any(named: 'subjectType'),
        from: any(named: 'from'),
        to: any(named: 'to'),
        forceRefresh: any(named: 'forceRefresh'),
      )).thenAnswer(answer);
}

void main() {
  group('AuditListBloc', () {
    late _MockRepo repo;

    setUp(() => repo = _MockRepo());

    test('a late answer for an OLD filter never overwrites the newer one',
        () async {
      final slow = Completer<CursorPage<AuditEventData>>();
      _stubList(repo, (inv) {
        final action = inv.namedArguments[#action] as String?;
        if (action == 'cycle.started') return slow.future;
        return Future.value(CursorPage(items: [buildAuditEvent(id: 'new')]));
      });
      final bloc = AuditListBloc(repo);

      bloc.add(const FilterAuditEvents('cycle.started'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const FilterAuditEvents('product.created'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // The first (slow) answer arrives last.
      slow.complete(CursorPage(items: [buildAuditEvent(id: 'old')]));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.actionFilter, 'product.created');
      expect(bloc.state.events.map((e) => e.id), ['new']);
      await bloc.close();
    });

    test('changing the filter empties the rows of the previous one at once',
        () async {
      final hold = Completer<CursorPage<AuditEventData>>();
      var first = true;
      _stubList(repo, (_) {
        if (first) {
          first = false;
          return Future.value(CursorPage(items: [buildAuditEvent(id: 'a')]));
        }
        return hold.future;
      });
      final bloc = AuditListBloc(repo)..add(const LoadAuditEvents());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.events, hasLength(1));

      bloc.add(const FilterAuditEvents('cycle.started'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.events, isEmpty);
      expect(bloc.state.status, AuditStatus.loading);
      hold.complete(const CursorPage(items: []));
      await bloc.close();
    });

    test('actor, subject type and period reach the repository together',
        () async {
      _stubList(repo, (_) async => const CursorPage(items: []));
      final bloc = AuditListBloc(repo);
      final from = DateTime(2026, 9, 1);
      final to = DateTime(2026, 9, 30);
      bloc.add(const FilterAuditEvents('cycle.started'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(ApplyAdvancedAuditFilters(
        actorId: 'u1',
        actorLabel: 'Dr Test',
        subjectType: 'App\\Domain\\Sterilization\\Models\\Cycle',
        from: from,
        to: to,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      verify(() => repo.list(
            cursor: any(named: 'cursor'),
            action: 'cycle.started',
            actorId: 'u1',
            subjectType: 'App\\Domain\\Sterilization\\Models\\Cycle',
            from: from,
            to: to,
            forceRefresh: any(named: 'forceRefresh'),
          )).called(1);
      await bloc.close();
    });

    test('a first-load failure is an error state with a French message',
        () async {
      _stubList(
        repo,
        (_) async => throw const ApiException(
          code: 'server_error',
          message: 'Erreur serveur.',
        ),
      );
      final bloc = AuditListBloc(repo)..add(const LoadAuditEvents());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.status, AuditStatus.failure);
      expect(bloc.state.error, isNotEmpty);
      await bloc.close();
    });
  });

  group('period filter', () {
    test('the picked end date includes the whole of that day', () {
      expect(endOfDay(DateTime(2026, 9, 30)), DateTime(2026, 9, 30, 23, 59, 59));
      // An explicit time is respected.
      final noon = DateTime(2026, 9, 30, 12, 15);
      expect(endOfDay(noon), noon);
    });

    test('from and to are sent as UTC instants, the end day included',
        () async {
      final dio = _MockDio();
      Map<String, dynamic>? sent;
      when(() => dio.get(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((inv) async {
        sent = inv.namedArguments[#queryParameters] as Map<String, dynamic>;
        return Response(
          requestOptions: RequestOptions(path: ''),
          data: {'data': []},
        );
      });
      await AuditRemoteDatasource(dio).list(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );
      expect(sent!['filter[from]'], DateTime(2026, 9, 1).toUtc().toIso8601String());
      expect(
        sent!['filter[to]'],
        DateTime(2026, 9, 30, 23, 59, 59).toUtc().toIso8601String(),
      );
    });
  });

  group('French action labels', () {
    test('real server actions are worded, not shown as raw codes', () {
      for (final code in [
        'stock.adjusted',
        'stock.issued',
        'stock.transferred',
        'alert.resolved',
        'cycle.submitted_for_release',
        'goods_receipt.created',
        'prosthetic_case.status_changed',
        'invitation.created',
        'inventory_count.closed',
        'label.recalled',
      ]) {
        expect(AuditEventData.actionLabels.containsKey(code), isTrue,
            reason: code);
      }
      final e = buildAuditEvent(action: 'stock.adjusted');
      expect(e.actionLabel, 'Ajustement de stock');
    });

    test('an action the app does not know yet still shows (its code)', () {
      expect(buildAuditEvent(action: 'future.thing').actionLabel, 'future.thing');
    });
  });

  group('AuditListScreen', () {
    late _MockRepo repo;

    setUp(() {
      repo = _MockRepo();
      if (GetIt.instance.isRegistered<AuditRepository>()) {
        GetIt.instance.unregister<AuditRepository>();
      }
      GetIt.instance.registerSingleton<AuditRepository>(repo);
    });

    tearDown(() => GetIt.instance.reset());

    testWidgets('"Autres actions…" lists every action and filters by it',
        (tester) async {
      _stubList(repo, (_) async => CursorPage(items: [buildAuditEvent()]));
      await pumpApp(tester, const AuditListScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Autres actions…'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('audit-action-list')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('audit-action-alert.resolved')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('audit-action-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const Key('audit-action-alert.resolved')));
      await tester.pumpAndSettle();

      verify(() => repo.list(
            cursor: any(named: 'cursor'),
            action: 'alert.resolved',
            actorId: any(named: 'actorId'),
            subjectType: any(named: 'subjectType'),
            from: any(named: 'from'),
            to: any(named: 'to'),
            forceRefresh: any(named: 'forceRefresh'),
          )).called(1);
      // The chosen action stays visible as the selected chip.
      expect(find.text('Alerte résolue'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a failed refresh keeps the rows and says they may be stale',
        (tester) async {
      var calls = 0;
      _stubList(repo, (_) async {
        calls++;
        if (calls == 1) return CursorPage(items: [buildAuditEvent()]);
        throw const ApiException(code: 'network', message: 'Hors ligne.');
      });
      await pumpApp(tester, const AuditListScreen());
      await tester.pumpAndSettle();
      BlocProvider.of<AuditListBloc>(
        tester.element(find.byType(Scaffold).first),
      ).add(const RefreshAuditEvents());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('list-stale-banner')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
