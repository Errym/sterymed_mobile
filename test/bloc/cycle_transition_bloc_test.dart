import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/features/cycles/data/models/cycle_release_data.dart';
import 'package:steriymed_mobile/features/cycles/data/repositories/cycle_repository.dart';
import 'package:steriymed_mobile/features/cycles/presentation/bloc/cycle_transition_bloc.dart';

import '../fixtures/cycle_fixture.dart';

class MockCycleRepository extends Mock implements CycleRepository {}

CycleReleaseData _buildRelease({
  CycleReleaseDecision decision = CycleReleaseDecision.compliant,
}) =>
    CycleReleaseData(
      id: 'release-1',
      cycleId: 'cycle-1',
      decision: decision,
      releasedAt: DateTime(2026, 9, 26, 10, 0),
    );

void main() {
  late MockCycleRepository repo;

  setUp(() {
    repo = MockCycleRepository();
  });

  group('CycleTransitionBloc', () {
    blocTest<CycleTransitionBloc, CycleTransitionState>(
      'StartCycle succeeds',
      build: () => CycleTransitionBloc(repo),
      setUp: () {
        when(() => repo.start('cycle-1'))
            .thenAnswer((_) async => buildCycle(status: 'running'));
      },
      act: (b) => b.add(const StartCycle('cycle-1')),
      expect: () => [
        isA<CycleTransitionState>().having(
          (s) => s.status,
          'status',
          CycleTransitionStatus.loading,
        ),
        isA<CycleTransitionState>()
            .having(
              (s) => s.status,
              'status',
              CycleTransitionStatus.success,
            )
            .having((s) => s.cycle?.status, 'cycle.status', 'running'),
      ],
    );

    blocTest<CycleTransitionBloc, CycleTransitionState>(
      'StartCycle failure surfaces the server message and error code',
      build: () => CycleTransitionBloc(repo),
      setUp: () {
        when(() => repo.start('cycle-1')).thenThrow(const ApiException(
          code: 'invalid_transition',
          message: 'Ce cycle ne peut pas être démarré.',
        ));
      },
      act: (b) => b.add(const StartCycle('cycle-1')),
      expect: () => [
        isA<CycleTransitionState>().having(
          (s) => s.status,
          'status',
          CycleTransitionStatus.loading,
        ),
        isA<CycleTransitionState>()
            .having(
              (s) => s.status,
              'status',
              CycleTransitionStatus.failure,
            )
            .having(
              (s) => s.error,
              'error',
              'Ce cycle ne peut pas être démarré.',
            )
            .having((s) => s.errorCode, 'errorCode', 'invalid_transition'),
      ],
    );

    blocTest<CycleTransitionBloc, CycleTransitionState>(
      'CompleteCycle succeeds',
      build: () => CycleTransitionBloc(repo),
      setUp: () {
        when(() => repo.complete('cycle-1'))
            .thenAnswer((_) async => buildCycle(status: 'completed'));
      },
      act: (b) => b.add(const CompleteCycle('cycle-1')),
      expect: () => [
        isA<CycleTransitionState>()
            .having((s) => s.status, 'status', CycleTransitionStatus.loading),
        isA<CycleTransitionState>()
            .having((s) => s.status, 'status', CycleTransitionStatus.success)
            .having((s) => s.cycle?.status, 'cycle.status', 'completed'),
      ],
    );

    blocTest<CycleTransitionBloc, CycleTransitionState>(
      'SubmitCycleForRelease succeeds',
      build: () => CycleTransitionBloc(repo),
      setUp: () {
        when(() => repo.submitForRelease('cycle-1')).thenAnswer(
          (_) async => buildCycle(status: 'awaiting_release'),
        );
      },
      act: (b) => b.add(const SubmitCycleForRelease('cycle-1')),
      expect: () => [
        isA<CycleTransitionState>()
            .having((s) => s.status, 'status', CycleTransitionStatus.loading),
        isA<CycleTransitionState>()
            .having((s) => s.status, 'status', CycleTransitionStatus.success)
            .having(
              (s) => s.cycle?.status,
              'cycle.status',
              'awaiting_release',
            ),
      ],
    );

    blocTest<CycleTransitionBloc, CycleTransitionState>(
      'ReleaseCycle(compliant) succeeds and carries the release record',
      build: () => CycleTransitionBloc(repo),
      setUp: () {
        when(() => repo.release(
              'cycle-1',
              decision: 'compliant',
              reason: null,
            )).thenAnswer((_) async => _buildRelease());
      },
      act: (b) => b.add(const ReleaseCycle(
        cycleId: 'cycle-1',
        decision: 'compliant',
      )),
      expect: () => [
        isA<CycleTransitionState>()
            .having((s) => s.status, 'status', CycleTransitionStatus.loading),
        isA<CycleTransitionState>()
            .having((s) => s.status, 'status', CycleTransitionStatus.success)
            .having(
              (s) => s.release?.decision,
              'release.decision',
              CycleReleaseDecision.compliant,
            ),
      ],
    );

    blocTest<CycleTransitionBloc, CycleTransitionState>(
      'ReleaseCycle(rejected) passes the mandatory reason through',
      build: () => CycleTransitionBloc(repo),
      setUp: () {
        when(() => repo.release(
              'cycle-1',
              decision: 'rejected',
              reason: 'Indicateur biologique positif',
            )).thenAnswer(
          (_) async => _buildRelease(decision: CycleReleaseDecision.rejected),
        );
      },
      act: (b) => b.add(const ReleaseCycle(
        cycleId: 'cycle-1',
        decision: 'rejected',
        reason: 'Indicateur biologique positif',
      )),
      expect: () => [
        isA<CycleTransitionState>()
            .having((s) => s.status, 'status', CycleTransitionStatus.loading),
        isA<CycleTransitionState>()
            .having((s) => s.status, 'status', CycleTransitionStatus.success)
            .having(
              (s) => s.release?.decision,
              'release.decision',
              CycleReleaseDecision.rejected,
            ),
      ],
      verify: (_) {
        verify(() => repo.release(
              'cycle-1',
              decision: 'rejected',
              reason: 'Indicateur biologique positif',
            )).called(1);
      },
    );

    blocTest<CycleTransitionBloc, CycleTransitionState>(
      'ResetCycleTransition returns to idle',
      build: () => CycleTransitionBloc(repo),
      seed: () => const CycleTransitionState(
        status: CycleTransitionStatus.failure,
        error: 'stale error',
      ),
      act: (b) => b.add(const ResetCycleTransition()),
      expect: () => [
        const CycleTransitionState(),
      ],
    );
  });
}
